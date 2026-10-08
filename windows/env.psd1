# The complete user environment (HKCU\Environment), applied by env.ps1.
#
# env.ps1 makes the registry match this file exactly: undeclared variables are
# removed, so whatever an installer adds surfaces as drift instead of piling
# up. Values are written as REG_EXPAND_SZ, so %NAME% resolves at logon.
@{
  # Order is resolution order. Machine PATH (System32, Git, dotnet) precedes it.
  Path = @(
    '%USERPROFILE%\.local\bin'               # uv python + tools, go install, wrappers
    '%USERPROFILE%\.local\share\mise\shims'  # every mise-managed toolchain and CLI
    '%USERPROFILE%\.local\share\cargo\bin'   # rustup proxies, cargo-installed tools
    '%LOCALAPPDATA%\Microsoft\WinGet\Links'  # winget portable symlinks
    'C:\Program Files\LLVM\bin'              # clangd, MSVC-target clang
    '%LOCALAPPDATA%\Programs\Microsoft VS Code\bin'
    '%LOCALAPPDATA%\agy\bin'                 # Antigravity CLI
    '%LOCALAPPDATA%\Microsoft\WindowsApps'   # Store execution aliases (pwsh, winget)
    # Written verbatim as winget writes it, so a mise upgrade finds it present
    # instead of appending a second copy.
    'C:\Users\olives\AppData\Local\Microsoft\WinGet\Packages\jdx.mise_Microsoft.Winget.Source_8wekyb3d8bbwe\mise\bin'
  )

  Vars = @{
    TEMP                  = '%USERPROFILE%\AppData\Local\Temp'
    TMP                   = '%USERPROFILE%\AppData\Local\Temp'

    # Toolchain homes: ~/.local/share holds the data, ~/.cache the caches.
    CARGO_HOME            = '%USERPROFILE%\.local\share\cargo'
    RUSTUP_HOME           = '%USERPROFILE%\.local\share\rustup'
    UV_PYTHON_INSTALL_DIR = '%USERPROFILE%\.local\share\uv\python'
    UV_TOOL_DIR           = '%USERPROFILE%\.local\share\uv\tools'
    UV_CACHE_DIR          = '%USERPROFILE%\.cache\uv'
    MISE_DATA_DIR         = '%USERPROFILE%\.local\share\mise'
    MISE_CACHE_DIR        = '%USERPROFILE%\.cache\mise'
    MISE_STATE_DIR        = '%USERPROFILE%\.local\state\mise'
    MISE_CONFIG_DIR       = '%USERPROFILE%\.config\mise'
    GOPATH                = '%USERPROFILE%\.local\share\go'
    GOBIN                 = '%USERPROFILE%\.local\bin'
    # Junction that mise's java postinstall hook repoints on every update.
    JAVA_HOME             = '%USERPROFILE%\.local\share\jdk-21'

    # Keep tools that default to ~/.<name> out of ~.
    IPYTHONDIR            = '%USERPROFILE%\.config\ipython'
    MPLCONFIGDIR          = '%USERPROFILE%\.config\matplotlib'
    KERAS_HOME            = '%USERPROFILE%\.local\share\keras'
    LESSHISTFILE          = '-'
  }
}
