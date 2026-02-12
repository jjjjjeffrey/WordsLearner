//
//  Model.swift
//  NavigationSplitViewTCA
//
//  Created by Michael Brünen on 10.12.25.
//

import Foundation

struct SidebarData: Equatable {
    let title: String = "Genres"

    let items: [ContentData] = [.hipHop, .metal, .pop]
}

struct ContentData: Equatable, Hashable, Identifiable {
    var id: String { title }
    let title: String
    let subtitle: String
    let items: [DetailData]

    static let hipHop = ContentData(
        title: "Hip Hop",
        subtitle: "Also known as rap music or simply rap",
        items: [.beyonce, .eminem, .fiftyCent]
    )

    static let metal = ContentData(
        title: "Heavy Metal",
        subtitle: "A genre of rock music",
        items: [.acdc, .blackSabbath, .metallica]
    )

    static let pop = ContentData(
        title: "Pop Music",
        subtitle: "A genre of popular music",
        items: [.billieEilish, .lanaDelRey, .taylorSwift]
    )
}

struct DetailData: Equatable, Hashable, Identifiable {
    var id: String { title }
    let title: String
    let subtitle: String
    let description: String

    static let beyonce = DetailData(
        title: "Beyoncé",
        subtitle: "American singer-songwriter, actress, and producer",
        description: "Born on August 16, 1981, in Houston, Texas"
    )
    static let eminem = DetailData(
        title: "Eminem",
        subtitle: "American rapper, songwriter, and record producer",
        description: "Born on February 12, 1972, in Compton, California"
    )
    static let fiftyCent = DetailData(
        title: "50 Cent",
        subtitle: "American rapper, songwriter, and record producer",
        description: "Born on February 12, 1972, in Compton, California"
    )

    static let acdc = DetailData(
        title: "AC/DC",
        subtitle: "American rock band",
        description: "Formed in 1973 in Seattle, Washington"
    )
    static let blackSabbath = DetailData(
        title: "Black Sabbath",
        subtitle: "English heavy metal band",
        description: "Formed in 1968 in Birmingham, England"
    )
    static let metallica = DetailData(
        title: "Metallica",
        subtitle: "American heavy metal band",
        description: "Formed in 1981 in Seattle, Washington"
    )

    static let billieEilish = DetailData(
        title: "Billie Eilish",
        subtitle: "American singer-songwriter and actress",
        description: "Born on August 16, 1997, in Brooklyn, New York"
    )
    static let lanaDelRey = DetailData(
        title: "Lana Del Rey",
        subtitle: "American singer-songwriter and actress",
        description: "Born on June 28, 1994, in Brooklyn, New York"
    )
    static let taylorSwift = DetailData(
        title: "Taylor Swift",
        subtitle: "American singer-songwriter",
        description: "Born on December 13, 1989, in Louisville, Kentucky"
    )
}
