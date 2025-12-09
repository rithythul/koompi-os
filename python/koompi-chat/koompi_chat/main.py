import sys
import asyncio
from PySide6.QtWidgets import (QApplication, QMainWindow, QWidget, QVBoxLayout, 
                               QHBoxLayout, QTextEdit, QLineEdit, QPushButton, QLabel)
from PySide6.QtCore import Qt, Slot
from PySide6.QtGui import QFont
from qasync import QEventLoop
from koompi_ai import query
try:
    from qt_material import apply_stylesheet
except ImportError:
    apply_stylesheet = None

class ChatWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("KOOMPI Assistant")
        self.resize(400, 600)
        
        # Central widget
        central_widget = QWidget()
        self.setCentralWidget(central_widget)
        layout = QVBoxLayout(central_widget)
        
        # Chat history
        self.history = QTextEdit()
        self.history.setReadOnly(True)
        self.history.setFont(QFont("Roboto", 10))
        layout.addWidget(self.history)
        
        # Input area
        input_layout = QHBoxLayout()
        self.input_field = QLineEdit()
        self.input_field.setPlaceholderText("Ask me anything...")
        self.input_field.returnPressed.connect(self.send_message)
        input_layout.addWidget(self.input_field)
        
        self.send_btn = QPushButton("Send")
        self.send_btn.clicked.connect(self.send_message)
        input_layout.addWidget(self.send_btn)
        
        layout.addLayout(input_layout)
        
        # Status bar
        self.status_label = QLabel("Ready")
        self.statusBar().addWidget(self.status_label)
        
        # Welcome message
        self.append_message("KOOMPI", "Hello! How can I help you today?")

    def append_message(self, sender: str, text: str):
        color = "#4CAF50" if sender == "KOOMPI" else "#2196F3"
        # Simple HTML formatting
        formatted_text = text.replace("\n", "<br>")
        self.history.append(f'<b style="color:{color}">{sender}:</b> {formatted_text}<br>')

    @Slot()
    def send_message(self):
        text = self.input_field.text().strip()
        if not text:
            return
            
        self.append_message("You", text)
        self.input_field.clear()
        self.status_label.setText("Thinking...")
        self.input_field.setDisabled(True)
        self.send_btn.setDisabled(True)
        
        # Run async task
        asyncio.create_task(self.process_query(text))

    async def process_query(self, text: str):
        try:
            response = await query(text)
            self.append_message("KOOMPI", response.text)
            self.status_label.setText(f"Ready (Confidence: {response.confidence:.0%})")
        except Exception as e:
            self.append_message("System", f"Error: {e}")
            self.status_label.setText("Error")
        finally:
            self.input_field.setDisabled(False)
            self.send_btn.setDisabled(False)
            self.input_field.setFocus()

def main():
    app = QApplication(sys.argv)
    loop = QEventLoop(app)
    asyncio.set_event_loop(loop)
    
    window = ChatWindow()
    
    if apply_stylesheet:
        apply_stylesheet(app, theme='dark_teal.xml')
        
    window.show()
    
    with loop:
        loop.run_forever()

if __name__ == "__main__":
    main()
