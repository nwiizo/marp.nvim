" Debug script for marp.nvim
" Run this with :source /path/to/debug_marp.vim

echo "=== Marp.nvim Debug Information ==="
echo ""

" Check if plugin is loaded
if exists('g:loaded_marp')
  echo "✓ g:loaded_marp is set: " . g:loaded_marp
else
  echo "✗ g:loaded_marp is NOT set"
endif

echo ""

" Check runtime path
echo "Runtime path includes:"
for path in split(&runtimepath, ',')
  if path =~ 'marp\.nvim'
    echo "  ✓ " . path
  endif
endfor

echo ""

" Check if Lua module can be loaded
try
  lua print("Attempting to load marp module...")
  lua local ok, marp = pcall(require, 'marp')
  lua if ok then print("✓ Lua module loaded successfully") else print("✗ Failed to load Lua module: " .. tostring(marp)) end
catch
  echo "✗ Error loading Lua module: " . v:exception
endtry

echo ""

" Check if commands exist
echo "Command existence:"
if exists(':MarpWatch')
  echo "  ✓ :MarpWatch exists"
else
  echo "  ✗ :MarpWatch does NOT exist"
endif

if exists(':MarpStop')
  echo "  ✓ :MarpStop exists"
else
  echo "  ✗ :MarpStop does NOT exist"
endif

if exists(':MarpPreview')
  echo "  ✓ :MarpPreview exists"
else
  echo "  ✗ :MarpPreview does NOT exist"
endif

echo ""

" Check plugin directory
let plugin_file = findfile('plugin/marp.vim', &runtimepath)
if !empty(plugin_file)
  echo "✓ Found plugin file at: " . plugin_file
else
  echo "✗ Plugin file not found in runtimepath"
endif

echo ""

" Check if plugin/marp.vim was sourced
echo "Checking scriptnames for marp.vim:"
let found = 0
for script in split(execute('scriptnames'), '\n')
  if script =~ 'marp\.vim'
    echo "  ✓ " . script
    let found = 1
  endif
endfor
if !found
  echo "  ✗ marp.vim not found in :scriptnames"
endif

echo ""
echo "=== End Debug Information ==="