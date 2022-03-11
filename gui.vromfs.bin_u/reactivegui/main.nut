#default:no-func-decl-sugar
#default:no-class-decl-sugar

require("reactiveGui/globals/darg_library.nut")
require("reactiveGui/globals/ui_library.nut")
require("consoleCmd.nut")

let widgets = require("reactiveGui/widgets.nut")
let { inspectorRoot } = require("%darg/components/inspector.nut")

return {
  size = flex()
  children = [
    widgets
    inspectorRoot
  ]
}
