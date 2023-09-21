//
//  SearchField.swift
//  Terminader
//
//  Created by Steven Huang on 9/21/23.
//

import SwiftUI

struct SearchField: View {
    var prompt: String?
    @Binding var text: String
    @State private var isEditing = false
    
    var body: some View {
        HStack {
            TextField(prompt ?? "Search", text: $text)
                .textFieldStyle(.roundedBorder)
                .onTapGesture {
                    isEditing = true
                }
        }
    }
}

@_documentation(visibility: private)
struct SearchField_Previews: PreviewProvider {
    @State private static var text = ""
    static var previews: some View {
        SearchField(text: $text)
    }
}
