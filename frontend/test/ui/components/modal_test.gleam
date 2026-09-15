import gleeunit/should
import ui/components/modal/modal

pub fn modal_config_keeps_accessible_close_contract_test() {
  let config =
    modal.Config(
      title: "Вход",
      close_label: "Закрыть окно",
      on_close: "close",
      children: [],
    )

  config.title |> should.equal("Вход")
  config.close_label |> should.equal("Закрыть окно")
  config.on_close |> should.equal("close")
}
