//! Main application logic for KOOMPI Files

use crate::file_item::FileItem;
use crate::icons;
use iced::widget::{
    button, column, container, horizontal_space, row, scrollable, text, text_input, Column, Row,
};
use iced::{alignment, Application, Command, Element, Length, Theme};
use std::path::PathBuf;

/// View mode for file listing
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum ViewMode {
    #[default]
    List,
    Grid,
}

/// Sort order for files
#[derive(Debug, Clone, Copy, PartialEq, Eq, Default)]
pub enum SortBy {
    #[default]
    Name,
    Size,
    Date,
    Type,
}

/// Application messages
#[derive(Debug, Clone)]
pub enum Message {
    // Navigation
    NavigateTo(PathBuf),
    GoBack,
    GoForward,
    GoUp,
    GoHome,
    Refresh,

    // File operations
    OpenItem(PathBuf),
    SelectItem(PathBuf),
    DeselectAll,

    // View options
    SetViewMode(ViewMode),
    SetSortBy(SortBy),
    ToggleHidden,
    ToggleSidebar,

    // Search
    SearchChanged(String),
    ClearSearch,

    // Sidebar
    GoToDocuments,
    GoToDownloads,
    GoToMusic,
    GoToPictures,
    GoToVideos,

    // Results
    DirectoryLoaded(Vec<FileItem>),
    ErrorOccurred(String),
}

/// Main application state
pub struct FilesApp {
    current_path: PathBuf,
    items: Vec<FileItem>,
    selected: Option<PathBuf>,
    history_back: Vec<PathBuf>,
    history_forward: Vec<PathBuf>,

    view_mode: ViewMode,
    sort_by: SortBy,
    show_hidden: bool,
    show_sidebar: bool,

    search_query: String,
    error_message: Option<String>,
    is_loading: bool,
}

impl Application for FilesApp {
    type Message = Message;
    type Theme = Theme;
    type Executor = iced::executor::Default;
    type Flags = ();

    fn new(_flags: ()) -> (Self, Command<Message>) {
        let home = dirs::home_dir().unwrap_or_else(|| PathBuf::from("/"));
        let app = Self {
            current_path: home.clone(),
            items: Vec::new(),
            selected: None,
            history_back: Vec::new(),
            history_forward: Vec::new(),
            view_mode: ViewMode::List,
            sort_by: SortBy::Name,
            show_hidden: false,
            show_sidebar: true,
            search_query: String::new(),
            error_message: None,
            is_loading: true,
        };

        let path = home;
        (app, Command::perform(load_directory(path), |result| {
            match result {
                Ok(items) => Message::DirectoryLoaded(items),
                Err(e) => Message::ErrorOccurred(e.to_string()),
            }
        }))
    }

    fn title(&self) -> String {
        format!("KOOMPI Files - {}", self.current_path.display())
    }

    fn update(&mut self, message: Message) -> Command<Message> {
        match message {
            Message::NavigateTo(path) => {
                self.history_back.push(self.current_path.clone());
                self.history_forward.clear();
                self.current_path = path.clone();
                self.selected = None;
                self.is_loading = true;
                return Command::perform(load_directory(path), |result| {
                    match result {
                        Ok(items) => Message::DirectoryLoaded(items),
                        Err(e) => Message::ErrorOccurred(e.to_string()),
                    }
                });
            }
            Message::GoBack => {
                if let Some(path) = self.history_back.pop() {
                    self.history_forward.push(self.current_path.clone());
                    self.current_path = path.clone();
                    self.selected = None;
                    self.is_loading = true;
                    return Command::perform(load_directory(path), |result| {
                        match result {
                            Ok(items) => Message::DirectoryLoaded(items),
                            Err(e) => Message::ErrorOccurred(e.to_string()),
                        }
                    });
                }
            }
            Message::GoForward => {
                if let Some(path) = self.history_forward.pop() {
                    self.history_back.push(self.current_path.clone());
                    self.current_path = path.clone();
                    self.selected = None;
                    self.is_loading = true;
                    return Command::perform(load_directory(path), |result| {
                        match result {
                            Ok(items) => Message::DirectoryLoaded(items),
                            Err(e) => Message::ErrorOccurred(e.to_string()),
                        }
                    });
                }
            }
            Message::GoUp => {
                if let Some(parent) = self.current_path.parent() {
                    let path = parent.to_path_buf();
                    self.history_back.push(self.current_path.clone());
                    self.history_forward.clear();
                    self.current_path = path.clone();
                    self.selected = None;
                    self.is_loading = true;
                    return Command::perform(load_directory(path), |result| {
                        match result {
                            Ok(items) => Message::DirectoryLoaded(items),
                            Err(e) => Message::ErrorOccurred(e.to_string()),
                        }
                    });
                }
            }
            Message::GoHome => {
                let home = dirs::home_dir().unwrap_or_else(|| PathBuf::from("/"));
                if home != self.current_path {
                    self.history_back.push(self.current_path.clone());
                    self.history_forward.clear();
                    self.current_path = home.clone();
                    self.selected = None;
                    self.is_loading = true;
                    return Command::perform(load_directory(home), |result| {
                        match result {
                            Ok(items) => Message::DirectoryLoaded(items),
                            Err(e) => Message::ErrorOccurred(e.to_string()),
                        }
                    });
                }
            }
            Message::Refresh => {
                let path = self.current_path.clone();
                self.is_loading = true;
                return Command::perform(load_directory(path), |result| {
                    match result {
                        Ok(items) => Message::DirectoryLoaded(items),
                        Err(e) => Message::ErrorOccurred(e.to_string()),
                    }
                });
            }
            Message::OpenItem(path) => {
                if path.is_dir() {
                    return Command::perform(async { path }, Message::NavigateTo);
                } else {
                    // Open file with default application
                    if let Err(e) = open::that(&path) {
                        self.error_message = Some(format!("Failed to open: {}", e));
                    }
                }
            }
            Message::SelectItem(path) => {
                self.selected = Some(path);
            }
            Message::DeselectAll => {
                self.selected = None;
            }
            Message::SetViewMode(mode) => {
                self.view_mode = mode;
            }
            Message::SetSortBy(sort) => {
                self.sort_by = sort;
                self.sort_items();
            }
            Message::ToggleHidden => {
                self.show_hidden = !self.show_hidden;
            }
            Message::ToggleSidebar => {
                self.show_sidebar = !self.show_sidebar;
            }
            Message::SearchChanged(query) => {
                self.search_query = query;
            }
            Message::ClearSearch => {
                self.search_query.clear();
            }
            Message::GoToDocuments => {
                if let Some(path) = dirs::document_dir() {
                    return Command::perform(async { path }, Message::NavigateTo);
                }
            }
            Message::GoToDownloads => {
                if let Some(path) = dirs::download_dir() {
                    return Command::perform(async { path }, Message::NavigateTo);
                }
            }
            Message::GoToMusic => {
                if let Some(path) = dirs::audio_dir() {
                    return Command::perform(async { path }, Message::NavigateTo);
                }
            }
            Message::GoToPictures => {
                if let Some(path) = dirs::picture_dir() {
                    return Command::perform(async { path }, Message::NavigateTo);
                }
            }
            Message::GoToVideos => {
                if let Some(path) = dirs::video_dir() {
                    return Command::perform(async { path }, Message::NavigateTo);
                }
            }
            Message::DirectoryLoaded(items) => {
                self.items = items;
                self.sort_items();
                self.is_loading = false;
                self.error_message = None;
            }
            Message::ErrorOccurred(error) => {
                self.error_message = Some(error);
                self.is_loading = false;
            }
        }
        Command::none()
    }

    fn view(&self) -> Element<Message> {
        let toolbar = self.view_toolbar();
        let path_bar = self.view_path_bar();

        let content = if self.show_sidebar {
            row![
                self.view_sidebar(),
                self.view_file_list(),
            ]
        } else {
            row![self.view_file_list()]
        };

        let main_content = column![
            toolbar,
            path_bar,
            content,
        ];

        container(main_content)
            .width(Length::Fill)
            .height(Length::Fill)
            .into()
    }

    fn theme(&self) -> Theme {
        Theme::Dark
    }
}

impl FilesApp {
    fn sort_items(&mut self) {
        match self.sort_by {
            SortBy::Name => self.items.sort(),
            SortBy::Size => {
                self.items.sort_by(|a, b| {
                    match (a.is_dir, b.is_dir) {
                        (true, false) => std::cmp::Ordering::Less,
                        (false, true) => std::cmp::Ordering::Greater,
                        _ => b.size.cmp(&a.size),
                    }
                });
            }
            SortBy::Date => {
                self.items.sort_by(|a, b| {
                    match (a.is_dir, b.is_dir) {
                        (true, false) => std::cmp::Ordering::Less,
                        (false, true) => std::cmp::Ordering::Greater,
                        _ => b.modified.cmp(&a.modified),
                    }
                });
            }
            SortBy::Type => {
                self.items.sort_by(|a, b| {
                    match (a.is_dir, b.is_dir) {
                        (true, false) => std::cmp::Ordering::Less,
                        (false, true) => std::cmp::Ordering::Greater,
                        _ => a.mime_type.cmp(&b.mime_type),
                    }
                });
            }
        }
    }

    fn view_toolbar(&self) -> Element<Message> {
        let back_btn = button(text(icons::ICON_BACK))
            .on_press_maybe(if !self.history_back.is_empty() {
                Some(Message::GoBack)
            } else {
                None
            })
            .padding(8);

        let forward_btn = button(text(icons::ICON_FORWARD))
            .on_press_maybe(if !self.history_forward.is_empty() {
                Some(Message::GoForward)
            } else {
                None
            })
            .padding(8);

        let up_btn = button(text(icons::ICON_UP))
            .on_press_maybe(if self.current_path.parent().is_some() {
                Some(Message::GoUp)
            } else {
                None
            })
            .padding(8);

        let home_btn = button(text(icons::ICON_HOME))
            .on_press(Message::GoHome)
            .padding(8);

        let refresh_btn = button(text(icons::ICON_REFRESH))
            .on_press(Message::Refresh)
            .padding(8);

        let search = text_input("Search...", &self.search_query)
            .on_input(Message::SearchChanged)
            .width(Length::Fixed(200.0))
            .padding(8);

        let view_list_btn = button(text(icons::ICON_VIEW_LIST))
            .on_press(Message::SetViewMode(ViewMode::List))
            .padding(8);

        let view_grid_btn = button(text(icons::ICON_VIEW_GRID))
            .on_press(Message::SetViewMode(ViewMode::Grid))
            .padding(8);

        container(
            row![
                back_btn,
                forward_btn,
                up_btn,
                home_btn,
                refresh_btn,
                horizontal_space(),
                search,
                horizontal_space(),
                view_list_btn,
                view_grid_btn,
            ]
            .spacing(4)
            .padding(8)
            .align_items(alignment::Alignment::Center)
        )
        .style(container::Appearance::default().with_background(iced::Color::from_rgb(0.15, 0.15, 0.15)))
        .width(Length::Fill)
        .into()
    }

    fn view_path_bar(&self) -> Element<Message> {
        let path_text = text(self.current_path.display().to_string())
            .size(14);

        container(
            row![path_text]
                .padding(8)
        )
        .style(container::Appearance::default().with_background(iced::Color::from_rgb(0.12, 0.12, 0.12)))
        .width(Length::Fill)
        .into()
    }

    fn view_sidebar(&self) -> Element<Message> {
        let home_btn = button(
            row![text(icons::ICON_HOME), text(" Home")]
                .spacing(8)
        )
        .on_press(Message::GoHome)
        .width(Length::Fill)
        .padding(8);

        let documents_btn = button(
            row![text(icons::ICON_DOCUMENTS), text(" Documents")]
                .spacing(8)
        )
        .on_press(Message::GoToDocuments)
        .width(Length::Fill)
        .padding(8);

        let downloads_btn = button(
            row![text(icons::ICON_DOWNLOADS), text(" Downloads")]
                .spacing(8)
        )
        .on_press(Message::GoToDownloads)
        .width(Length::Fill)
        .padding(8);

        let music_btn = button(
            row![text(icons::ICON_MUSIC), text(" Music")]
                .spacing(8)
        )
        .on_press(Message::GoToMusic)
        .width(Length::Fill)
        .padding(8);

        let pictures_btn = button(
            row![text(icons::ICON_PICTURES), text(" Pictures")]
                .spacing(8)
        )
        .on_press(Message::GoToPictures)
        .width(Length::Fill)
        .padding(8);

        let videos_btn = button(
            row![text(icons::ICON_VIDEOS), text(" Videos")]
                .spacing(8)
        )
        .on_press(Message::GoToVideos)
        .width(Length::Fill)
        .padding(8);

        let sidebar_content = column![
            text("Places").size(12),
            home_btn,
            documents_btn,
            downloads_btn,
            music_btn,
            pictures_btn,
            videos_btn,
        ]
        .spacing(4)
        .padding(8);

        container(sidebar_content)
            .style(container::Appearance::default().with_background(iced::Color::from_rgb(0.1, 0.1, 0.1)))
            .width(Length::Fixed(180.0))
            .height(Length::Fill)
            .into()
    }

    fn view_file_list(&self) -> Element<Message> {
        let filtered_items: Vec<&FileItem> = self.items
            .iter()
            .filter(|item| {
                // Filter hidden files
                if !self.show_hidden && item.is_hidden {
                    return false;
                }
                // Filter by search query
                if !self.search_query.is_empty() {
                    return item.name.to_lowercase().contains(&self.search_query.to_lowercase());
                }
                true
            })
            .collect();

        if self.is_loading {
            return container(text("Loading..."))
                .width(Length::Fill)
                .height(Length::Fill)
                .center_x()
                .center_y()
                .into();
        }

        if let Some(error) = &self.error_message {
            return container(
                column![
                    text("Error").size(20),
                    text(error).size(14),
                ]
                .spacing(8)
            )
            .width(Length::Fill)
            .height(Length::Fill)
            .center_x()
            .center_y()
            .into();
        }

        if filtered_items.is_empty() {
            return container(text("Empty folder"))
                .width(Length::Fill)
                .height(Length::Fill)
                .center_x()
                .center_y()
                .into();
        }

        match self.view_mode {
            ViewMode::List => self.view_list(&filtered_items),
            ViewMode::Grid => self.view_grid(&filtered_items),
        }
    }

    fn view_list(&self, items: &[&FileItem]) -> Element<Message> {
        // Header row
        let header = row![
            text("Name").width(Length::FillPortion(3)),
            text("Size").width(Length::FillPortion(1)),
            text("Modified").width(Length::FillPortion(2)),
        ]
        .spacing(16)
        .padding(8);

        // File rows
        let rows: Vec<Element<Message>> = items
            .iter()
            .map(|item| {
                let is_selected = self.selected.as_ref() == Some(&item.path);
                let bg_color = if is_selected {
                    iced::Color::from_rgb(0.2, 0.4, 0.6)
                } else {
                    iced::Color::TRANSPARENT
                };

                let item_row = button(
                    row![
                        text(format!("{} {}", item.icon(), item.name))
                            .width(Length::FillPortion(3)),
                        text(item.size_string())
                            .width(Length::FillPortion(1)),
                        text(item.date_string())
                            .width(Length::FillPortion(2)),
                    ]
                    .spacing(16)
                    .padding(4)
                )
                .on_press(Message::OpenItem(item.path.clone()))
                .width(Length::Fill);

                container(item_row)
                    .style(container::Appearance::default().with_background(bg_color))
                    .into()
            })
            .collect();

        let file_list = Column::with_children(rows).spacing(2);

        scrollable(
            column![
                header,
                file_list,
            ]
        )
        .width(Length::Fill)
        .height(Length::Fill)
        .into()
    }

    fn view_grid(&self, items: &[&FileItem]) -> Element<Message> {
        const ITEMS_PER_ROW: usize = 5;

        let rows: Vec<Element<Message>> = items
            .chunks(ITEMS_PER_ROW)
            .map(|chunk| {
                let row_items: Vec<Element<Message>> = chunk
                    .iter()
                    .map(|item| {
                        let is_selected = self.selected.as_ref() == Some(&item.path);
                        let bg_color = if is_selected {
                            iced::Color::from_rgb(0.2, 0.4, 0.6)
                        } else {
                            iced::Color::TRANSPARENT
                        };

                        let item_content = column![
                            text(item.icon()).size(48),
                            text(&item.name).size(12),
                        ]
                        .align_items(alignment::Alignment::Center)
                        .spacing(4);

                        let item_btn = button(item_content)
                            .on_press(Message::OpenItem(item.path.clone()))
                            .padding(8)
                            .width(Length::Fixed(100.0))
                            .height(Length::Fixed(100.0));

                        container(item_btn)
                            .style(container::Appearance::default().with_background(bg_color))
                            .into()
                    })
                    .collect();

                Row::with_children(row_items)
                    .spacing(8)
                    .into()
            })
            .collect();

        scrollable(
            Column::with_children(rows)
                .spacing(8)
                .padding(8)
        )
        .width(Length::Fill)
        .height(Length::Fill)
        .into()
    }
}

/// Load directory contents asynchronously
async fn load_directory(path: PathBuf) -> Result<Vec<FileItem>, std::io::Error> {
    let mut items = Vec::new();

    let mut entries = tokio::fs::read_dir(&path).await?;
    while let Some(entry) = entries.next_entry().await? {
        if let Some(item) = FileItem::from_path(entry.path()) {
            items.push(item);
        }
    }

    Ok(items)
}
