"""KOOMPI Chat - AI Assistant GUI Application.

A Qt-based chat interface for the KOOMPI AI assistant with support for:
- Natural language queries about Linux, Windows, macOS
- KOOMPI OS system management
- Programming help
- Computer education
"""

import sys
import asyncio
from PySide6.QtWidgets import (
    QApplication, QMainWindow, QWidget, QVBoxLayout,
    QHBoxLayout, QTextEdit, QLineEdit, QPushButton, QLabel,
    QFrame, QScrollArea
)
from PySide6.QtCore import Qt, Slot, QTimer
from PySide6.QtGui import QFont, QIcon, QKeySequence, QShortcut
from qasync import QEventLoop
from koompi_ai import query

try:
    from qt_material import apply_stylesheet
    MATERIAL_AVAILABLE = True
except ImportError:
    apply_stylesheet = None
    MATERIAL_AVAILABLE = False


WELCOME_MESSAGE = """សួស្តី! Hello! I'm KOOMPI Assistant.

I can help you with:
• **KOOMPI OS** - installation, updates, snapshots, rollback
• **Linux** - commands, configuration, troubleshooting
• **Windows/macOS** - cross-platform workflows
• **Programming** - Python, Rust, JavaScript, and more

Just ask naturally, like "how do I install KDE?" or "what's the Windows equivalent of grep?"
"""


class ChatWindow(QMainWindow):
    """Main chat window for KOOMPI Assistant."""
    
    def __init__(self):
        super().__init__()
        self.setWindowTitle("KOOMPI Assistant")
        self.resize(500, 700)
        self.setMinimumSize(400, 500)
        
        # Track offline status
        self._is_offline = False
        
        # Central widget
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout(central_widget)
        layout.setContentsMargins(10, 10, 10, 10)
        layout.setSpacing(10)
        
        # Header
        header = QLabel("🤖 KOOMPI Assistant")
        header.setFont(QFont("Roboto", 14, QFont.Bold))
        header.setAlignment(Qt.AlignCenter)
        layout.addWidget(header)
        
        # Chat history with better styling
        self.history = QTextEdit()
        self.history.setReadOnly(True)
        self.history.setFont(QFont("Roboto", 11))
        self.history.setStyleSheet("""
            QTextEdit {
                background-color: #1e1e2e;
                color: #cdd6f4;
                border: 1px solid #45475a;
                border-radius: 8px;
                padding: 10px;
            }
        """)
        layout.addWidget(self.history, stretch=1)
        
        # Suggestions bar
        suggestions_layout = QHBoxLayout()
        suggestions = ["How to install?", "Update system", "Create snapshot", "Help"]
        for suggestion in suggestions:
            btn = QPushButton(suggestion)
            btn.setStyleSheet("""
                QPushButton {
                    background-color: #313244;
                    color: #cdd6f4;
                    border: 1px solid #45475a;
                    border-radius: 15px;
                    padding: 5px 12px;
                    font-size: 10px;
                }
                QPushButton:hover {
                    background-color: #45475a;
                }
            """)
            btn.clicked.connect(lambda checked, s=suggestion: self.use_suggestion(s))
            suggestions_layout.addWidget(btn)
        suggestions_layout.addStretch()
        layout.addLayout(suggestions_layout)
        
        # Input area
        input_layout = QHBoxLayout()
        input_layout.setSpacing(8)
        
        self.input_field = QLineEdit()
        self.input_field.setPlaceholderText("Ask me anything about computers...")
        self.input_field.setFont(QFont("Roboto", 11))
        self.input_field.setStyleSheet("""
            QLineEdit {
                background-color: #313244;
                color: #cdd6f4;
                border: 1px solid #45475a;
                border-radius: 20px;
                padding: 10px 15px;
            }
            QLineEdit:focus {
                border-color: #89b4fa;
            }
        """)
        self.input_field.returnPressed.connect(self.send_message)
        input_layout.addWidget(self.input_field, stretch=1)
        
        self.send_btn = QPushButton("Send")
        self.send_btn.setFont(QFont("Roboto", 11, QFont.Bold))
        self.send_btn.setStyleSheet("""
            QPushButton {
                background-color: #89b4fa;
                color: #1e1e2e;
                border: none;
                border-radius: 20px;
                padding: 10px 20px;
            }
            QPushButton:hover {
                background-color: #b4befe;
            }
            QPushButton:disabled {
                background-color: #45475a;
                color: #6c7086;
            }
        """)
        self.send_btn.clicked.connect(self.send_message)
        input_layout.addWidget(self.send_btn)
        
        layout.addLayout(input_layout)
        
        # Status bar with offline indicator
        self.status_label = QLabel("Ready")
        self.status_label.setStyleSheet("color: #a6adc8;")
        self.statusBar().addWidget(self.status_label)
        
        self.offline_indicator = QLabel("")
        self.statusBar().addPermanentWidget(self.offline_indicator)
        
        # Keyboard shortcuts
        QShortcut(QKeySequence("Ctrl+L"), self, self.clear_history)
        QShortcut(QKeySequence("Escape"), self, self.input_field.clear)
        
        # Welcome message
        self.append_message("KOOMPI", WELCOME_MESSAGE)
    
    def use_suggestion(self, text: str):
        """Fill input with suggestion and send."""
        self.input_field.setText(text)
        self.send_message()
    
    def clear_history(self):
        """Clear chat history."""
        self.history.clear()
        self.append_message("KOOMPI", "Chat cleared. How can I help you?")

    def append_message(self, sender: str, text: str):
        """Add a message to chat history with formatting."""
        if sender == "KOOMPI":
            color = "#a6e3a1"  # Green for assistant
            icon = "🤖"
        elif sender == "You":
            color = "#89b4fa"  # Blue for user
            icon = "👤"
        else:
            color = "#f9e2af"  # Yellow for system
            icon = "⚠️"
        
        # Convert markdown-like formatting
        formatted_text = text
        # Bold: **text** -> <b>text</b>
        import re
        formatted_text = re.sub(r'\*\*(.+?)\*\*', r'<b>\1</b>', formatted_text)
        # Code: `text` -> <code>text</code>
        formatted_text = re.sub(r'`(.+?)`', r'<code style="background:#313244;padding:2px 4px;border-radius:3px;">\1</code>', formatted_text)
        # Newlines
        formatted_text = formatted_text.replace("\n", "<br>")
        # Bullet points
        formatted_text = formatted_text.replace("• ", "・ ")
        
        self.history.append(
            f'<div style="margin:8px 0;">'
            f'<span style="color:{color};font-weight:bold;">{icon} {sender}</span><br>'
            f'<span style="color:#cdd6f4;margin-left:20px;">{formatted_text}</span>'
            f'</div>'
        )
        
        # Scroll to bottom
        self.history.verticalScrollBar().setValue(
            self.history.verticalScrollBar().maximum()
        )

    @Slot()
    def send_message(self):
        """Handle send button/enter press."""
        text = self.input_field.text().strip()
        if not text:
            return
        
        self.append_message("You", text)
        self.input_field.clear()
        self.status_label.setText("🤔 Thinking...")
        self.input_field.setDisabled(True)
        self.send_btn.setDisabled(True)
        
        # Run async task
        asyncio.create_task(self.process_query(text))

    async def process_query(self, text: str):
        """Process user query through AI."""
        try:
            response = await query(text)
            self.append_message("KOOMPI", response.text)
            
            # Update status with source info
            if response.is_offline:
                self.status_label.setText("Ready (Offline mode)")
                self.offline_indicator.setText("📴 Offline")
                self.offline_indicator.setStyleSheet("color: #f9e2af;")
            else:
                self.status_label.setText(f"Ready • {response.source}")
                self.offline_indicator.setText("🌐 Online")
                self.offline_indicator.setStyleSheet("color: #a6e3a1;")
                
        except Exception as e:
            self.append_message("System", f"Error: {e}")
            self.status_label.setText("Error occurred")
        finally:
            self.input_field.setDisabled(False)
            self.send_btn.setDisabled(False)
            self.input_field.setFocus()


def main():
    """Application entry point."""
    app = QApplication(sys.argv)
    app.setApplicationName("KOOMPI Assistant")
    app.setOrganizationName("KOOMPI")
    
    # Set up async event loop
    loop = QEventLoop(app)
    asyncio.set_event_loop(loop)
    
    # Create main window
    window = ChatWindow()
    
    # Apply theme if available
    if MATERIAL_AVAILABLE and apply_stylesheet:
        apply_stylesheet(app, theme='dark_teal.xml')
    else:
        # Fallback dark theme
        app.setStyleSheet("""
            QMainWindow, QWidget {
                background-color: #1e1e2e;
                color: #cdd6f4;
            }
            QStatusBar {
                background-color: #181825;
                color: #a6adc8;
            }
        """)
    
    window.show()
    
    with loop:
        loop.run_forever()


if __name__ == "__main__":
    main()
