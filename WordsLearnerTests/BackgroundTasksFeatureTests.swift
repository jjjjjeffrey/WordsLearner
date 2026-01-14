//
//  BackgroundTasksFeatureTests.swift
//  WordsLearnerTests
//
//  Created by Jeffrey on 1/14/26.
//

import ComposableArchitecture
import DependenciesTestSupport
import Foundation
import SQLiteData
import Testing

@testable import WordsLearner

@MainActor
struct BackgroundTasksFeatureTests {

  // MARK: - Helpers

  private func makeStore(
    backgroundTaskManager: BackgroundTaskManagerClient? = nil
  ) -> TestStoreOf<BackgroundTasksFeature> {
    TestStore(initialState: BackgroundTasksFeature.State()) {
      BackgroundTasksFeature()
    } withDependencies: {
      try! $0.bootstrapDatabase()
      if let backgroundTaskManager {
        $0.backgroundTaskManager = backgroundTaskManager
      }
    }
  }

  // MARK: - Initial State Tests

  @Test
  func initialState_loadsSeedDataAndComputedProperties() async throws {
    let store = makeStore()

    // Seed data in DatabaseConfiguration.swift inserts 4 BackgroundTask rows.
    #expect(store.state.tasks.count == 4)
    #expect(store.state.isEmpty == false)

    // By default we are not generating until the current task ID is set.
    #expect(store.state.currentGeneratingTaskId == nil)
    #expect(store.state.isGenerating == false)

    // Seed statuses: pending (1), completed (1), generating (1), failed (1)
    #expect(store.state.pendingTasksCount == 1)
    #expect(store.state.completedTasksCount == 2)  // completed + failed
  }

  // MARK: - onAppear Action Tests

  @Test
  func onAppear_sendsSyncCurrentTaskId() async throws {
    let store = makeStore(
      backgroundTaskManager: BackgroundTaskManagerClient(
        startProcessingLoop: { },
        stopProcessingLoop: { },
        addTask: { _, _, _ in },
        getCurrentTaskId: { nil },
        isProcessing: { false },
        getPendingTasksCount: { 0 },
        regenerateTask: { _ in }
      )
    )

    // `syncCurrentTaskId` starts a long-living polling loop; we only want to assert it is triggered.
    store.exhaustivity = .off
    await store.send(.onAppear)
    await store.receive(.syncCurrentTaskId)
  }

  // MARK: - syncCurrentTaskId / currentTaskIdUpdated Tests

  @Test
  func currentTaskIdUpdated_updatesGeneratingState() async throws {
    let store = makeStore()

    let id = UUID()
    await store.send(.currentTaskIdUpdated(id)) {
      $0.currentGeneratingTaskId = id
    }
    #expect(store.state.isGenerating == true)

    await store.send(.currentTaskIdUpdated(nil)) {
      $0.currentGeneratingTaskId = nil
    }
    #expect(store.state.isGenerating == false)
  }

  @Test
  func syncCurrentTaskId_emitsCurrentTaskIdUpdated_andCanBeCancelled() async throws {
    let id = UUID()
    let store = makeStore(
      backgroundTaskManager: BackgroundTaskManagerClient(
        startProcessingLoop: { },
        stopProcessingLoop: { },
        addTask: { _, _, _ in },
        getCurrentTaskId: { id },
        isProcessing: { true },
        getPendingTasksCount: { 0 },
        regenerateTask: { _ in }
      )
    )

    let task = await store.send(.syncCurrentTaskId)
    await store.receive(.currentTaskIdUpdated(id)) {
      $0.currentGeneratingTaskId = id
    }

    // Cancel while the effect is sleeping to stop the infinite loop.
    await task.cancel()
  }

  // MARK: - removeTask Action Tests

  @Test
  func removeTask_deletesFromDatabaseAndUpdatesFetch() async throws {
    let store = makeStore()

    #expect(store.state.tasks.count == 4)
    let toRemove = try #require(store.state.tasks.first)
    let toRemoveId = toRemove.id

    await store.send(.removeTask(toRemoveId))
    await store.finish()

    #expect(store.state.tasks.count == 3)
    #expect(!store.state.tasks.contains(where: { $0.id == toRemoveId }))
  }

  // MARK: - regenerateTask Action Tests

  @Test
  func regenerateTask_callsDependencyWithTaskId() async throws {
    actor RegeneratedIDs {
      var ids: [UUID] = []
      func append(_ id: UUID) { ids.append(id) }
      func snapshot() -> [UUID] { ids }
    }

    let regenerated = RegeneratedIDs()

    let store = makeStore(
      backgroundTaskManager: BackgroundTaskManagerClient(
        startProcessingLoop: { },
        stopProcessingLoop: { },
        addTask: { _, _, _ in },
        getCurrentTaskId: { nil },
        isProcessing: { false },
        getPendingTasksCount: { 0 },
        regenerateTask: { id in await regenerated.append(id) }
      )
    )

    let failed = try #require(store.state.tasks.first(where: { $0.taskStatus == .failed }))

    await store.send(.regenerateTask(failed.id))
    await store.finish()

    #expect(await regenerated.snapshot() == [failed.id])
  }

  // MARK: - clearCompletedTasks Action Tests

  @Test
  func clearCompletedTasks_removesCompletedAndFailedOnly() async throws {
    let store = makeStore()

    #expect(store.state.tasks.count == 4)
    #expect(store.state.pendingTasksCount == 1)
    #expect(store.state.completedTasksCount == 2)

    await store.send(.clearCompletedTasks)
    await store.finish()

    // Remaining: pending + generating
    #expect(store.state.tasks.count == 2)
    #expect(store.state.tasks.allSatisfy { $0.taskStatus == .pending || $0.taskStatus == .generating })
    #expect(store.state.pendingTasksCount == 1)
    #expect(store.state.completedTasksCount == 0)
  }

  // MARK: - clearAllTasks Action Tests

  @Test
  func clearAllTasks_stopsLoop_deletesAllRows_restartsLoop() async throws {
    actor StartStopCounts {
      var startCalls = 0
      var stopCalls = 0
      func incStart() { startCalls += 1 }
      func incStop() { stopCalls += 1 }
      func snapshot() -> (start: Int, stop: Int) { (startCalls, stopCalls) }
    }

    let counts = StartStopCounts()

    let store = makeStore(
      backgroundTaskManager: BackgroundTaskManagerClient(
        startProcessingLoop: { await counts.incStart() },
        stopProcessingLoop: { await counts.incStop() },
        addTask: { _, _, _ in },
        getCurrentTaskId: { nil },
        isProcessing: { false },
        getPendingTasksCount: { 0 },
        regenerateTask: { _ in }
      )
    )

    #expect(store.state.tasks.count == 4)

    await store.send(.clearAllTasks)
    await store.finish()

    let snapshot = await counts.snapshot()
    #expect(snapshot.stop == 1)
    #expect(snapshot.start == 1)
    #expect(store.state.tasks.isEmpty)
    #expect(store.state.isEmpty == true)
  }

  // MARK: - viewComparisonHistory / delegate Action Tests

  @Test
  func viewComparisonHistory_sendsDelegate() async throws {
    let store = makeStore()

    let comparison = ComparisonHistory(
      id: UUID(),
      word1: "w1",
      word2: "w2",
      sentence: "s",
      response: "r",
      date: Date(),
      isRead: false
    )

    await store.send(.viewComparisonHistory(comparison))
    await store.receive(.delegate(.comparisonSelected(comparison)))
  }

  @Test
  func delegateAction_noStateChange() async throws {
    let store = makeStore()

    let comparison = ComparisonHistory(
      id: UUID(),
      word1: "w1",
      word2: "w2",
      sentence: "s",
      response: "r",
      date: Date(),
      isRead: false
    )

    await store.send(.delegate(.comparisonSelected(comparison)))
  }

  // MARK: - Database Integration Tests

  @Test
  func tasks_areOrderedByCreatedAtDescending() async throws {
    let store = makeStore()

    let tasks = store.state.tasks
    #expect(tasks.count == 4)

    // Seed order: Date() (pending "accept"), -3600 (completed "advice"), -7200 (generating "complement"), -10800 (failed "principle")
    #expect(tasks.first?.word1 == "accept")
    #expect(tasks.dropFirst().first?.word1 == "advice")
    #expect(tasks.dropFirst(2).first?.word1 == "complement")
    #expect(tasks.dropFirst(3).first?.word1 == "principle")
  }
}

