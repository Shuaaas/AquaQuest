# Shop design

Open `res://Scene/UI/shop_ui.tscn` to edit the UI with native Godot controls. Panel/Layout/Header contains the title, points balance, and Close button. Columns contains Catalog (scrollable item buttons) and Paper (description and purchase details). The local Theme uses the existing wood, button, and parchment textures and Godot bundled font family. Buttons are created from existing catalog entries in ShopUI.gd.

Below 700 pixels wide, select an item to open its detail view; Item list returns to browsing. The details scroll independently while Total, Status, and Buy stay reachable. Close/Escape uses the existing ShopManager close signal and pause ownership.

ShopManager remains responsible for prices, stock, one-time items, carrying limits, funds, and transactions. UI selection never buys an item. The Buy button revalidates through the existing buy_item method. Single-item limits show a fixed quantity of one; stackable items retain minus/plus and numeric quantity. Selling remains unavailable. Missing icons remain empty rather than using invented equipment art.

Tests cover purchase eligibility and real transactions, stock/owned refresh, bulk quantity, empty catalog, phone list/detail navigation, pause release, and panel/button bounds at desktop, small landscape, and portrait dimensions. Physical Android touch and safe-area testing remain manual.
