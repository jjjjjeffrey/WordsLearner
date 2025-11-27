//
//  CustomTextFieldStyle.swift
//  WordsLearner
//
//  Created by Jeffrey on 11/12/25.
//

import SwiftUI

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(AppColors.fieldBackground)
                    .stroke(AppColors.fieldBorder, lineWidth: 1)
            )
    }
}
