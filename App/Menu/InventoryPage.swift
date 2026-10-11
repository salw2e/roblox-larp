import SwiftUI
import SalBloxKit

struct InventoryPage: View {
    @EnvironmentObject var store: Store
    let open: (Page) -> Void
    var body: some View {
        ScrollView {
            if store.profile.items.isEmpty {
                Text("Your inventory is empty. Get items in the Marketplace.").font(.builder(14.5)).foregroundStyle(Color.faint).padding(.top, 40)
            }
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12, alignment: .top), GridItem(.flexible(), spacing: 12, alignment: .top),
                                GridItem(.flexible(), alignment: .top)], spacing: 20) {
                ForEach(store.profile.items) { item in
                    Button { open(.item(item)) } label: { ItemCard(item: item) }
                        .buttonStyle(PressStyle()).accessibilityIdentifier("inventoryPageItem")
                }
            }
            .padding(.leading, 15).padding(.trailing, 14).padding(.top, 12)
        }
        .page("Inventory")
    }
}
