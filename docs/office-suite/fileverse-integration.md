# Fileverse Integration Guide

**Purpose:** Document how KOOMPI Office integrates Fileverse components for privacy-first office functionality.

---

## 1. About Fileverse

[Fileverse](https://fileverse.io) is an open-source, decentralized office suite designed as a privacy-focused alternative to Google Workspace and Microsoft 365.

### Core Components

| Component | Purpose | Technology | License |
|-----------|---------|-----------|---------|
| **dDocs** | Word processor | React, TipTap, IPFS | Open Source |
| **dSheets** | Spreadsheet | React, blockchain data | Open Source |
| **dSlides** | Presentations | React | Open Source |
| **dPages** | Wiki/Notion alternative | React | Open Source |

### Key Features We're Using

1. **Rich Text Editor (dDocs)**
   - Block-based editing (similar to Notion)
   - Markdown support
   - Real-time collaboration architecture
   - JSON-based document format

2. **End-to-End Encryption**
   - Client-side encryption
   - Privacy by design
   - No server-side data access

3. **Modular Architecture**
   - React components
   - NPM packages
   - Easy integration

### Key Features We're NOT Using

1. **Web3/Blockchain**
   - Ethereum integration
   - Token gating
   - On-chain storage
   - *Reason:* KOOMPI OS is offline-first, no mandatory blockchain

2. **IPFS/Arweave Storage**
   - Decentralized file storage
   - *Reason:* Using local filesystem by default
   - *Note:* May add as optional cloud sync

3. **Wallet Authentication**
   - MetaMask, WalletConnect
   - *Reason:* Using local-only mode

---

## 2. Integration Strategy

### 2.1 Architecture Approach

```
Fileverse Components (Web)
         ↓
   Strip Web3 Features
         ↓
   Add Local Storage
         ↓
   Wrap in Tauri Desktop
         ↓
KOOMPI Office (Native Apps)
```

### 2.2 What We Keep

✅ **React Components**
- UI components
- Editor logic
- Styling (Tailwind CSS)

✅ **Document Format**
- JSON-based structure
- ProseMirror schema
- Block-based content

✅ **Collaboration Architecture**
- CRDT-ready structure
- Y.js compatibility (future)

✅ **Privacy Features**
- No telemetry
- Client-side processing
- Encrypted storage option

### 2.3 What We Modify

🔄 **Storage Backend**
- **Original:** IPFS/Arweave
- **KOOMPI:** Local filesystem + IndexedDB
- **Optional:** WebDAV, IPFS (user enabled)

🔄 **Authentication**
- **Original:** Web3 wallets
- **KOOMPI:** Local-only (no auth)
- **Optional:** KOOMPI user accounts

🔄 **Networking**
- **Original:** P2P via libp2p
- **KOOMPI:** Local-first
- **Optional:** LAN sync, cloud sync

### 2.4 What We Add

➕ **MS Office Format Conversion**
- DOCX import/export
- XLSX import/export
- PPTX import/export

➕ **Desktop Integration**
- Native menus
- File associations
- System tray
- Notifications

➕ **Offline Features**
- Full offline functionality
- Auto-save to local disk
- Crash recovery

---

## 3. Component Integration

### 3.1 dDocs (Word Processor)

#### NPM Package

```bash
npm install @fileverse-dev/ddoc
```

#### Basic Integration

```typescript
import { DdocEditor } from '@fileverse-dev/ddoc';
import '@fileverse-dev/ddoc/styles';

function KoompiWriter() {
  const [content, setContent] = useState<JSONContent>(null);

  return (
    <DdocEditor
      initialContent={content}
      onChange={(newContent) => {
        setContent(newContent);
        // Auto-save to local filesystem via Tauri
        invoke('save_document', { content: newContent });
      }}
      isPreviewMode={false}
      // Disable collaboration (no network)
      enableCollaboration={false}
      // Use local storage instead of IPFS
      enableIndexeddbSync={true}
    />
  );
}
```

#### Configuration

```typescript
const ddocProps: DdocProps = {
  // Core
  initialContent: documentJson,
  onChange: handleContentChange,
  isPreviewMode: false,
  
  // Storage (disable network features)
  enableCollaboration: false,
  enableIndexeddbSync: true,
  
  // UI
  isNavbarVisible: true,
  documentStyling: {
    background: '#ffffff',
    textColor: '#333333',
    fontFamily: 'Inter, sans-serif',
  },
  
  // KOOMPI customization
  editorCanvasClassNames: 'koompi-editor',
  renderNavbar: () => <KoompiMenubar />,
  renderThemeToggle: () => <KoompiThemeToggle />,
};
```

### 3.2 dSheets (Spreadsheet)

**Status:** Needs evaluation

#### If Available

```typescript
import { DsheetEditor } from '@fileverse-dev/dsheet'; // Hypothetical

function KoompiSheets() {
  return (
    <DsheetEditor
      initialData={spreadsheetData}
      onChange={handleDataChange}
      enableCharts={true}
      enableFormulas={true}
      // Disable blockchain features
      enableOnChainData={false}
    />
  );
}
```

#### Alternative: Luckysheet

If dSheets not ready, use Luckysheet:

```typescript
import Luckysheet from 'luckysheet';

function KoompiSheets() {
  useEffect(() => {
    Luckysheet.create({
      container: 'luckysheet',
      data: spreadsheetData,
      onChange: handleDataChange,
    });
  }, []);

  return <div id="luckysheet" />;
}
```

### 3.3 dSlides (Presentations)

**Status:** Needs evaluation

#### Option 1: dSlides (if available)

```typescript
import { DslidesEditor } from '@fileverse-dev/dslides'; // Hypothetical

function KoompiSlides() {
  return (
    <DslidesEditor
      initialSlides={slidesData}
      onChange={handleSlidesChange}
      presentationMode={false}
    />
  );
}
```

#### Option 2: Build on dDocs

Use dDocs with custom slide CSS:

```typescript
function KoompiSlides() {
  return (
    <DdocEditor
      initialContent={slidesContent}
      onChange={handleChange}
      documentStyling={{
        background: 'linear-gradient(135deg, #667eea 0%, #764ba2 100%)',
        canvasBackground: '#ffffff',
      }}
      // Custom slide navigation
      isPresentationMode={isPresenting}
      editorCanvasClassNames="slide-layout"
    />
  );
}
```

---

## 4. Tauri Backend Integration

### 4.1 File Operations

**Rust Backend (`src/file_ops.rs`):**

```rust
use tauri::api::dialog;
use std::fs;

#[tauri::command]
async fn save_document(path: String, content: String) -> Result<(), String> {
    fs::write(path, content)
        .map_err(|e| e.to_string())
}

#[tauri::command]
async fn load_document(path: String) -> Result<String, String> {
    fs::read_to_string(path)
        .map_err(|e| e.to_string())
}

#[tauri::command]
async fn open_file_dialog() -> Result<Option<String>, String> {
    dialog::blocking::FileDialogBuilder::new()
        .add_filter("KOOMPI Documents", &["koompi-doc", "docx"])
        .pick_file()
        .map(|path| path.map(|p| p.to_string_lossy().to_string()))
        .ok_or_else(|| "No file selected".to_string())
}
```

**Frontend Calls:**

```typescript
import { invoke } from '@tauri-apps/api';

async function saveDocument(content: JSONContent) {
  try {
    await invoke('save_document', {
      path: currentFilePath,
      content: JSON.stringify(content),
    });
    showNotification('Document saved');
  } catch (error) {
    showError('Failed to save: ' + error);
  }
}
```

### 4.2 Format Conversion

**Rust Backend (`src/converters/docx_import.rs`):**

```rust
use docx_rs::read_docx;

#[tauri::command]
async fn import_docx(path: String) -> Result<String, String> {
    let file = fs::File::open(path)
        .map_err(|e| e.to_string())?;
    
    let docx = read_docx(file)
        .map_err(|e| e.to_string())?;
    
    // Convert to Fileverse JSON format
    let json = convert_docx_to_fileverse_json(docx)?;
    
    Ok(serde_json::to_string(&json).unwrap())
}
```

**Frontend:**

```typescript
async function openDocxFile(path: string) {
  const json = await invoke<string>('import_docx', { path });
  const content = JSON.parse(json);
  setEditorContent(content);
}
```

---

## 5. Disabling Web3 Features

### 5.1 Fileverse Code Modifications

**Fork Fileverse repositories:**

```bash
git clone https://github.com/fileverse/fileverse-ddoc.git
cd fileverse-ddoc
git checkout -b koompi-modifications
```

**Disable Web3 imports:**

```diff
- import { useWallet } from '@/hooks/useWallet';
- import { uploadToIPFS } from '@/utils/ipfs';
+ // Web3 features disabled for KOOMPI OS
```

**Remove blockchain dependencies:**

```json
// package.json
{
  "dependencies": {
-   "ethers": "^6.0.0",
-   "@walletconnect/web3-provider": "^1.8.0",
-   "ipfs-http-client": "^60.0.0",
    "@fileverse-dev/ddoc": "^1.0.0"
  }
}
```

### 5.2 Configuration Flags

**Create KOOMPI build:**

```typescript
// config.ts
export const KOOMPI_CONFIG = {
  WEB3_ENABLED: false,
  IPFS_ENABLED: false,
  LOCAL_STORAGE_ONLY: true,
  CLOUD_SYNC_OPTIONAL: true,
};

// In components
if (KOOMPI_CONFIG.WEB3_ENABLED) {
  // Web3 features (disabled)
} else {
  // Local-only mode (default)
}
```

---

## 6. Offline-First Implementation

### 6.1 Storage Strategy

```
User Creates Document
         ↓
  Save to IndexedDB (immediate)
         ↓
  Debounce 30s
         ↓
  Write to Filesystem (persistent)
         ↓
  [Cloud Sync Enabled?]
         ↓ Yes
  Upload to WebDAV/IPFS
```

### 6.2 Auto-Save Implementation

```typescript
function useAutoSave(content: JSONContent, filePath: string) {
  const saveToIndexedDB = async (data: JSONContent) => {
    await db.documents.put({
      id: filePath,
      content: data,
      lastModified: new Date(),
    });
  };

  const saveToFilesystem = async (data: JSONContent) => {
    await invoke('save_document', {
      path: filePath,
      content: JSON.stringify(data),
    });
  };

  // Immediate save to IndexedDB
  useEffect(() => {
    saveToIndexedDB(content);
  }, [content]);

  // Debounced save to filesystem
  useEffect(() => {
    const timer = setTimeout(() => {
      saveToFilesystem(content);
    }, 30000); // 30 seconds

    return () => clearTimeout(timer);
  }, [content]);
}
```

---

## 7. Testing Fileverse Integration

### 7.1 Component Tests

```typescript
describe('dDocs Integration', () => {
  it('should render editor without Web3', () => {
    const { getByRole } = render(
      <DdocEditor
        initialContent={null}
        enableCollaboration={false}
        enableIndexeddbSync={true}
      />
    );
    
    expect(getByRole('textbox')).toBeInTheDocument();
  });

  it('should save to local storage', async () => {
    const handleChange = jest.fn();
    const { getByRole } = render(
      <DdocEditor onChange={handleChange} />
    );
    
    const editor = getByRole('textbox');
    fireEvent.input(editor, { target: { textContent: 'Hello' } });
    
    await waitFor(() => {
      expect(handleChange).toHaveBeenCalled();
    });
  });
});
```

### 7.2 Integration Tests

```bash
# Test offline mode
npm run test:offline

# Test DOCX conversion
npm run test:docx-roundtrip

# Test auto-save
npm run test:autosave
```

---

## 8. Maintenance Strategy

### 8.1 Upstream Updates

**Track Fileverse releases:**

```bash
# Add upstream remote
git remote add upstream https://github.com/fileverse/fileverse-ddoc.git

# Pull updates
git fetch upstream
git merge upstream/main --strategy=ours

# Resolve conflicts (keep KOOMPI modifications)
```

### 8.2 Long-term Strategy

**Option 1: Fork Maintenance**
- Maintain KOOMPI fork indefinitely
- Cherry-pick Fileverse bug fixes
- Add KOOMPI-specific features

**Option 2: Contribute Upstream**
- Submit PR to Fileverse for "local-only mode"
- Make Web3 features optional
- Benefit from upstream improvements

**Recommendation:** Start with Option 1, transition to Option 2 if collaboration opportunity arises.

---

## 9. Resources

### Official Fileverse Links
- Website: https://fileverse.io
- GitHub: https://github.com/fileverse
- dDocs: https://github.com/fileverse/fileverse-ddoc
- Documentation: https://docs.fileverse.io

### KOOMPI Resources
- Office Suite Design: [technical-specification.md](technical-specification.md)
- Roadmap: [roadmap.md](roadmap.md)
- Project Repository: https://github.com/koompi/koompi-os (koompi-office branch)

---

**Status:** Design Phase  
**Last Updated:** 2025-12-19  
**Next Steps:** Audit Fileverse component availability and quality
