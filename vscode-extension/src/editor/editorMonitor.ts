import * as vscode from 'vscode';

export interface EditorPosition {
  line: number;
  character: number;
}

export interface EditorRange {
  start: EditorPosition;
  end: EditorPosition;
}

export interface DiagnosticSummary {
  errorCount: number;
  warningCount: number;
}

export interface EditorState {
  activeFileUri: string | null;
  relativePath: string | null;
  languageId: string | null;
  cursorPosition: EditorPosition | null;
  selectionRange: EditorRange | null;
  workspaceFolders: string[];
  diagnostics: DiagnosticSummary;
  activeContent?: string | null;
  lineCount?: number;
  tabSize?: number;
  insertSpaces?: boolean;
  timestamp: number;
}

export class EditorMonitor implements vscode.Disposable {
  private readonly _onDidChangeEditorState = new vscode.EventEmitter<EditorState>();
  public readonly onDidChangeEditorState: vscode.Event<EditorState> = this._onDidChangeEditorState.event;

  private _currentState: EditorState;
  private readonly _disposables: vscode.Disposable[] = [];
  private _debounceTimer: NodeJS.Timeout | null = null;
  private readonly _debounceMs = 250;

  constructor() {
    this._currentState = this.computeEditorState();
    this._registerListeners();
  }

  private _registerListeners(): void {
    // Active editor changes
    this._disposables.push(
      vscode.window.onDidChangeActiveTextEditor(() => {
        this._updateStateImmediately();
      })
    );

    // Cursor position and selection changes
    this._disposables.push(
      vscode.window.onDidChangeTextEditorSelection((event) => {
        if (event.textEditor === vscode.window.activeTextEditor) {
          this._updateStateImmediately();
        }
      })
    );

    // Diagnostics changes (debounced to avoid performance hit on rapid typing)
    this._disposables.push(
      vscode.languages.onDidChangeDiagnostics((event) => {
        const activeUri = vscode.window.activeTextEditor?.document.uri;
        if (activeUri && event.uris.some((uri) => uri.toString() === activeUri.toString())) {
          this._scheduleDebouncedUpdate();
        }
      })
    );

    // Workspace folder changes
    this._disposables.push(
      vscode.workspace.onDidChangeWorkspaceFolders(() => {
        this._updateStateImmediately();
      })
    );

    // Document text changes (debounced to broadcast live typing changes)
    this._disposables.push(
      vscode.workspace.onDidChangeTextDocument((event) => {
        const activeDoc = vscode.window.activeTextEditor?.document;
        if (activeDoc && event.document.uri.toString() === activeDoc.uri.toString()) {
          this._scheduleDebouncedUpdate();
        }
      })
    );
  }

  public computeEditorState(): EditorState {
    const activeEditor = vscode.window.activeTextEditor;
    const document = activeEditor?.document;
    const activeFileUri = document?.uri.toString() ?? null;

    let relativePath: string | null = null;
    if (document) {
      relativePath = vscode.workspace.asRelativePath(document.uri);
    }

    let cursorPosition: EditorPosition | null = null;
    let selectionRange: EditorRange | null = null;

    if (activeEditor && activeEditor.selection) {
      const selection = activeEditor.selection;
      cursorPosition = {
        line: selection.active.line,
        character: selection.active.character,
      };
      selectionRange = {
        start: {
          line: selection.start.line,
          character: selection.start.character,
        },
        end: {
          line: selection.end.line,
          character: selection.end.character,
        },
      };
    }

    const workspaceFolders = (vscode.workspace.workspaceFolders ?? []).map(
      (folder) => folder.uri.toString()
    );

    // Compute diagnostics count for active document
    let errorCount = 0;
    let warningCount = 0;
    let activeContent: string | null = null;
    let lineCount = 0;
    let tabSize = 2;
    let insertSpaces = true;

    if (document) {
      lineCount = document.lineCount;
      const text = document.getText();
      // Cap at 500KB to prevent WebSocket memory bloat
      if (text.length <= 500000) {
        activeContent = text;
      }

      const diagnostics = vscode.languages.getDiagnostics(document.uri);
      for (const diag of diagnostics) {
        if (diag.severity === vscode.DiagnosticSeverity.Error) {
          errorCount++;
        } else if (diag.severity === vscode.DiagnosticSeverity.Warning) {
          warningCount++;
        }
      }
    }

    if (activeEditor) {
      if (typeof activeEditor.options.tabSize === 'number') {
        tabSize = activeEditor.options.tabSize;
      }
      if (typeof activeEditor.options.insertSpaces === 'boolean') {
        insertSpaces = activeEditor.options.insertSpaces;
      }
    }

    return {
      activeFileUri,
      relativePath,
      languageId: document?.languageId ?? null,
      cursorPosition,
      selectionRange,
      workspaceFolders,
      diagnostics: {
        errorCount,
        warningCount,
      },
      activeContent,
      lineCount,
      tabSize,
      insertSpaces,
      timestamp: Date.now(),
    };
  }

  private _updateStateImmediately(): void {
    if (this._debounceTimer) {
      clearTimeout(this._debounceTimer);
      this._debounceTimer = null;
    }
    this._currentState = this.computeEditorState();
    this._onDidChangeEditorState.fire(this._currentState);
  }

  private _scheduleDebouncedUpdate(): void {
    if (this._debounceTimer) {
      clearTimeout(this._debounceTimer);
    }
    this._debounceTimer = setTimeout(() => {
      this._debounceTimer = null;
      this._currentState = this.computeEditorState();
      this._onDidChangeEditorState.fire(this._currentState);
    }, this._debounceMs);
  }

  public getCurrentState(): EditorState {
    return this._currentState;
  }

  public dispose(): void {
    if (this._debounceTimer) {
      clearTimeout(this._debounceTimer);
      this._debounceTimer = null;
    }
    this._onDidChangeEditorState.dispose();
    for (const d of this._disposables) {
      d.dispose();
    }
    this._disposables.length = 0;
  }
}
