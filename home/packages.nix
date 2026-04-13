{ pkgs, ... }:

{
  home.packages = with pkgs; [
    wl-clipboard
    keymapp
    libnotify
  ];

  xdg.configFile."touchegg/touchegg.conf".text = ''
    <touchegg>
      <settings>
        <property name="animation_delay">0</property>
        <property name="expiration_time">500</property>
        <property name="color">auto</property>
        <property name="borderColor">auto</property>
      </settings>
      <application name="All">
        <!-- 3 Finger Swipe Up → KDE Übersicht via KWin DBus -->
        <gesture type="SWIPE" fingers="3" direction="UP">
          <action type="RUN_COMMAND">
            <repeat>false</repeat>
            <command>dbus-send --session --type=method_call --dest=org.kde.KWin /Effects org.kde.kwin.Effects.toggleEffect string:overview</command>
            <on>begin</on>
          </action>
        </gesture>
        <!-- 3 Finger Swipe Down → Desktop anzeigen via KWin DBus -->
        <gesture type="SWIPE" fingers="3" direction="DOWN">
          <action type="RUN_COMMAND">
            <repeat>false</repeat>
            <command>dbus-send --session --type=method_call --dest=org.kde.KWin /KWin org.kde.KWin.showingDesktop boolean:true</command>
            <on>begin</on>
          </action>
        </gesture>
        <!-- 4 Finger Swipe Left/Right → Virtuellen Desktop wechseln -->
        <gesture type="SWIPE" fingers="4" direction="LEFT">
          <action type="CHANGE_DESKTOP">
            <direction>next</direction>
            <animate>true</animate>
          </action>
        </gesture>
        <gesture type="SWIPE" fingers="4" direction="RIGHT">
          <action type="CHANGE_DESKTOP">
            <direction>previous</direction>
            <animate>true</animate>
          </action>
        </gesture>
      </application>
    </touchegg>
  '';

  services.nextcloud-client = {
    enable = true;
    startInBackground = true;
  };
}
