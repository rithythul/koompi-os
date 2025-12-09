//! Network settings page

use iced::widget::{button, column, container, row, scrollable, text, toggler};
use iced::{Element, Length};

/// WiFi network entry
#[derive(Debug, Clone)]
pub struct WifiNetwork {
    pub ssid: String,
    pub signal_strength: i32, // 0-100
    pub secured: bool,
    pub connected: bool,
}

/// Network settings state
#[derive(Debug, Clone)]
pub struct NetworkSettings {
    pub wifi_enabled: bool,
    pub available_networks: Vec<WifiNetwork>,
    pub ethernet_connected: bool,
    pub airplane_mode: bool,
}

impl Default for NetworkSettings {
    fn default() -> Self {
        Self {
            wifi_enabled: true,
            available_networks: vec![
                WifiNetwork {
                    ssid: "KOOMPI-Network".to_string(),
                    signal_strength: 85,
                    secured: true,
                    connected: true,
                },
                WifiNetwork {
                    ssid: "Office-WiFi".to_string(),
                    signal_strength: 72,
                    secured: true,
                    connected: false,
                },
                WifiNetwork {
                    ssid: "Guest-Network".to_string(),
                    signal_strength: 45,
                    secured: false,
                    connected: false,
                },
            ],
            ethernet_connected: false,
            airplane_mode: false,
        }
    }
}

/// Network page messages
#[derive(Debug, Clone)]
pub enum NetworkMessage {
    WifiToggled(bool),
    AirplaneModeToggled(bool),
    ConnectToNetwork(String),
    DisconnectNetwork,
    RefreshNetworks,
}

impl NetworkSettings {
    pub fn update(&mut self, message: NetworkMessage) {
        match message {
            NetworkMessage::WifiToggled(enabled) => {
                self.wifi_enabled = enabled;
                if !enabled {
                    // Disconnect when WiFi is disabled
                    for network in &mut self.available_networks {
                        network.connected = false;
                    }
                }
            }
            NetworkMessage::AirplaneModeToggled(enabled) => {
                self.airplane_mode = enabled;
                if enabled {
                    self.wifi_enabled = false;
                    for network in &mut self.available_networks {
                        network.connected = false;
                    }
                }
            }
            NetworkMessage::ConnectToNetwork(ssid) => {
                // Disconnect from current network
                for network in &mut self.available_networks {
                    network.connected = false;
                }
                // Connect to new network
                if let Some(network) = self.available_networks.iter_mut().find(|n| n.ssid == ssid) {
                    network.connected = true;
                }
            }
            NetworkMessage::DisconnectNetwork => {
                for network in &mut self.available_networks {
                    network.connected = false;
                }
            }
            NetworkMessage::RefreshNetworks => {
                // TODO: Scan for networks
            }
        }
    }

    pub fn view(&self) -> Element<NetworkMessage> {
        let title = text("Network").size(24);

        // Airplane mode
        let airplane_row = row![
            text("✈️  Airplane Mode").width(Length::FillPortion(1)),
            toggler(None::<String>, self.airplane_mode, NetworkMessage::AirplaneModeToggled)
                .width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // WiFi toggle
        let wifi_row = row![
            text("📶  WiFi").width(Length::FillPortion(1)),
            toggler(None::<String>, self.wifi_enabled, NetworkMessage::WifiToggled)
                .width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // Ethernet status
        let ethernet_status = if self.ethernet_connected {
            "Connected"
        } else {
            "Not Connected"
        };
        let ethernet_row = row![
            text("🔌  Ethernet").width(Length::FillPortion(1)),
            text(ethernet_status).width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        let mut content = column![title, airplane_row, wifi_row, ethernet_row,].spacing(8);

        // WiFi networks list (only if WiFi is enabled)
        if self.wifi_enabled && !self.airplane_mode {
            let networks_title = row![
                text("Available Networks").size(18),
                button(text("🔄 Refresh"))
                    .on_press(NetworkMessage::RefreshNetworks)
                    .padding(4),
            ]
            .spacing(16);

            content = content.push(networks_title);

            let network_rows: Vec<Element<NetworkMessage>> = self
                .available_networks
                .iter()
                .map(|network| {
                    let signal_icon = if network.signal_strength > 75 {
                        "📶"
                    } else if network.signal_strength > 50 {
                        "📶"
                    } else if network.signal_strength > 25 {
                        "📶"
                    } else {
                        "📶"
                    };

                    let lock_icon = if network.secured { "🔒" } else { "" };

                    let connect_btn = if network.connected {
                        button(text("Disconnect"))
                            .on_press(NetworkMessage::DisconnectNetwork)
                            .padding(4)
                    } else {
                        button(text("Connect"))
                            .on_press(NetworkMessage::ConnectToNetwork(network.ssid.clone()))
                            .padding(4)
                    };

                    let status_text = if network.connected {
                        text("Connected").size(12)
                    } else {
                        text("").size(12)
                    };

                    row![
                        text(format!("{} {} {}", signal_icon, network.ssid, lock_icon))
                            .width(Length::FillPortion(2)),
                        status_text.width(Length::FillPortion(1)),
                        connect_btn,
                    ]
                    .spacing(16)
                    .padding(8)
                    .into()
                })
                .collect();

            let networks_list = scrollable(
                column(network_rows)
                    .spacing(4)
            )
            .height(Length::Fixed(200.0));

            content = content.push(networks_list);
        }

        container(content.padding(16))
            .width(Length::Fill)
            .height(Length::Fill)
            .into()
    }
}
