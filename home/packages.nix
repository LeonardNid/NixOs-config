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
        <property name="animation_delay">150</property>
        <property name="expiration_time">3000</property>
        <property name="color">auto</property>
        <property name="borderColor">auto</property>
      </settings>
      <application name="All">
        <!-- 3 Finger Swipe Up → KDE Übersicht (Meta+W) -->
        <gesture type="SWIPE" fingers="3" direction="UP">
          <action type="SEND_KEYS">
            <repeat>false</repeat>
            <modifiers>super</modifiers>
            <keys>W</keys>
          </action>
        </gesture>
        <!-- 3 Finger Swipe Down → Desktop anzeigen (Meta+D) -->
        <gesture type="SWIPE" fingers="3" direction="DOWN">
          <action type="SEND_KEYS">
            <repeat>false</repeat>
            <modifiers>super</modifiers>
            <keys>D</keys>
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
