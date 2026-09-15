import QtQuick
import qs.Commons
import qs.Ui

BarIndicator {
  id: root

  // shell.firstPartyServiceFor() looks the id up verbatim in the service map,
  // which is keyed by the id of the plugin that actually loaded — so on a
  // machine where omarchy.notifications has been cloned and disabled, asking
  // for the built-in id returns null and this indicator goes dead. Resolve the
  // clone the way the registry does before falling back to the plain lookup.
  readonly property var notificationService: {
    var shell = bar?.shell
    if (!shell) return null
    var registry = shell.pluginRegistry
    if (registry && typeof registry.resolveEnabledId === "function") {
      var resolved = registry.resolveEnabledId("omarchy.notifications")
      var service = shell.serviceFor(resolved)
      if (service) return service
    }
    return shell.firstPartyServiceFor("omarchy.notifications")
  }
  readonly property bool dnd: notificationService ? notificationService.doNotDisturb : false

  active: dnd
  activeText: "󰂛"
  inactiveText: "󰂛"
  activeTooltipText: "Allow Notifications"
  inactiveTooltipText: "Silence Notifications"

  onPressed: function() {
    if (root.notificationService) {
      root.notificationService.setDoNotDisturb(!root.notificationService.doNotDisturb)
    }
  }
}
