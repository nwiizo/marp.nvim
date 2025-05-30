if exists('g:loaded_marp')
  finish
endif
let g:loaded_marp = 1

" Commands
command! MarpWatch lua require('marp').watch()
command! MarpStop lua require('marp').stop()
command! MarpStopAll lua require('marp').stop_all()
command! MarpPreview lua require('marp').preview()
command! MarpList lua require('marp').list_active()
command! MarpInfo lua require('marp').info()
command! MarpCopyPath lua require('marp').copy_html_path()
command! MarpDebug lua require('marp').debug()

" Export commands
command! -nargs=? -complete=customlist,s:complete_export_formats MarpExport lua require('marp').export(<q-args>)

" Theme commands
command! -nargs=1 -complete=customlist,s:complete_themes MarpTheme lua require('marp').set_theme(<q-args>)

" Snippet commands
command! -nargs=1 -complete=customlist,s:complete_snippets MarpSnippet lua require('marp').insert_snippet(<q-args>)

" Completion functions
function! s:complete_export_formats(A, L, P)
  return ['html', 'pdf', 'pptx', 'png', 'jpeg']
endfunction

function! s:complete_themes(A, L, P)
  return ['default', 'gaia', 'uncover']
endfunction

function! s:complete_snippets(A, L, P)
  return ['title', 'columns', 'image', 'bg_image', 'center', 'speaker_notes']
endfunction