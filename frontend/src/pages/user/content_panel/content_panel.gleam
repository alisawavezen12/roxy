import app/message.{type Message, SelectUserTab}
import app/model.{type UserTab, Board, Wall}
import lustre/attribute
import lustre/element.{type Element}
import lustre/element/html
import pages/user/content_panel/board/board
import pages/user/content_panel/wall/wall
import ui/components/tabs/tabs

pub fn stylesheet() -> Element(message) {
  html.div([attribute.class("content-panel__styles")], [
    html.link([
      attribute.rel("stylesheet"),
      attribute.href("/pages/user/content_panel/content_panel.css"),
    ]),
    tabs.stylesheet(),
    wall.stylesheet(),
    board.stylesheet(),
  ])
}

pub fn view(active_tab: UserTab, post_content: String) -> Element(Message) {
  html.section([attribute.class("content-panel")], [
    html.div([attribute.class("content-panel__tabs")], [
      tabs.view(tabs.Config(
        tabs: [
          tabs.Tab(id: Wall, label: "Wall"),
          tabs.Tab(id: Board, label: "Board"),
        ],
        active: active_tab,
        on_select: SelectUserTab,
      )),
    ]),
    html.div([attribute.class("content-panel__body")], [
      content(active_tab, post_content),
    ]),
  ])
}

fn content(active_tab: UserTab, post_content: String) -> Element(Message) {
  case active_tab {
    Wall -> wall.view(post_content)
    Board -> board.view()
  }
}
