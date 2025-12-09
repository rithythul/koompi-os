//! Main application logic for System Settings

use crate::pages::{
    about::{AboutMessage, AboutSettings},
    appearance::{AppearanceMessage, AppearanceSettings},
    display::{DisplayMessage, DisplaySettings},
    network::{NetworkMessage, NetworkSettings},
    sound::{SoundMessage, SoundSettings},
};
use iced::widget::{button, column, container, row, scrollable, text};
use iced::{Application, Command, Element, Length, Theme};

/// Settings pages
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum Page {
    #[default]
    Display,
    Appearance,
    Sound,
    Network,
    About,
}

/// Sidebar item for navigation
struct SidebarItem {
    page: Page,
    icon: &'static str,
    label: &'static str,
}

const SIDEBAR_ITEMS: &[SidebarItem] = &[
    SidebarItem {
        page: Page::Display,
        icon: "🖥️",
        label: "Display",
    },
    SidebarItem {
        page: Page::Appearance,
        icon: "🎨",
        label: "Appearance",
    },
    SidebarItem {
        page: Page::Sound,
        icon: "🔊",
        label: "Sound",
    },
    SidebarItem {
        page: Page::Network,
        icon: "📶",
        label: "Network",
    },
    SidebarItem {
        page: Page::About,
        icon: "ℹ️",
        label: "About",
    },
];

/// Application messages
#[derive(Debug, Clone)]
pub enum Message {
    NavigateTo(Page),
    Display(DisplayMessage),
    Appearance(AppearanceMessage),
    Sound(SoundMessage),
    Network(NetworkMessage),
    About(AboutMessage),
}

/// Main application state
pub struct SettingsApp {
    current_page: Page,
    display: DisplaySettings,
    appearance: AppearanceSettings,
    sound: SoundSettings,
    network: NetworkSettings,
    about: AboutSettings,
}

impl Application for SettingsApp {
    type Message = Message;
    type Theme = Theme;
    type Executor = iced::executor::Default;
    type Flags = ();

    fn new(_flags: ()) -> (Self, Command<Message>) {
        let app = Self {
            current_page: Page::default(),
            display: DisplaySettings::default(),
            appearance: AppearanceSettings::default(),
            sound: SoundSettings::default(),
            network: NetworkSettings::default(),
            about: AboutSettings::default(),
        };
        (app, Command::none())
    }

    fn title(&self) -> String {
        let page_name = match self.current_page {
            Page::Display => "Display",
            Page::Appearance => "Appearance",
            Page::Sound => "Sound",
            Page::Network => "Network",
            Page::About => "About",
        };
        format!("KOOMPI Settings - {}", page_name)
    }

    fn update(&mut self, message: Message) -> Command<Message> {
        match message {
            Message::NavigateTo(page) => {
                self.current_page = page;
            }
            Message::Display(msg) => {
                self.display.update(msg);
            }
            Message::Appearance(msg) => {
                self.appearance.update(msg);
            }
            Message::Sound(msg) => {
                self.sound.update(msg);
            }
            Message::Network(msg) => {
                self.network.update(msg);
            }
            Message::About(msg) => {
                self.about.update(msg);
            }
        }
        Command::none()
    }

    fn view(&self) -> Element<Message> {
        let sidebar = self.view_sidebar();
        let content = self.view_content();

        let main_layout = row![sidebar, content];

        container(main_layout)
            .width(Length::Fill)
            .height(Length::Fill)
            .into()
    }

    fn theme(&self) -> Theme {
        // Use appearance settings to determine theme
        match self.appearance.theme.as_str() {
            "Light" => Theme::Light,
            "Dark" => Theme::Dark,
            _ => Theme::Dark, // Default to dark
        }
    }
}

impl SettingsApp {
    fn view_sidebar(&self) -> Element<Message> {
        let title = text("Settings").size(20);

        let items: Vec<Element<Message>> = SIDEBAR_ITEMS
            .iter()
            .map(|item| {
                let is_selected = self.current_page == item.page;

                let btn = button(
                    row![text(item.icon), text(item.label)]
                        .spacing(12)
                        .padding(4)
                )
                .on_press(Message::NavigateTo(item.page))
                .width(Length::Fill)
                .padding(8);

                if is_selected {
                    btn.into()
                } else {
                    btn.into()
                }
            })
            .collect();

        let sidebar_content = column![title]
            .push(scrollable(column(items).spacing(4)))
            .spacing(16)
            .padding(16);

        container(sidebar_content)
            .width(Length::Fixed(200.0))
            .height(Length::Fill)
            .style(container::Appearance::default().with_background(iced::Color::from_rgb(0.1, 0.1, 0.1)))
            .into()
    }

    fn view_content(&self) -> Element<Message> {
        let content: Element<Message> = match self.current_page {
            Page::Display => self.display.view().map(Message::Display),
            Page::Appearance => self.appearance.view().map(Message::Appearance),
            Page::Sound => self.sound.view().map(Message::Sound),
            Page::Network => self.network.view().map(Message::Network),
            Page::About => self.about.view().map(Message::About),
        };

        container(scrollable(content))
            .width(Length::Fill)
            .height(Length::Fill)
            .padding(8)
            .into()
    }
}
