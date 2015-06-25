" A special thanks goes out to John Leimon <jleimon@gmail.com>
" for his more complete C/C++ version,
" which served as a great basis for understanding
" regex matching in Vim

" Allow users to configure the plugin to auto start for certain filetypes
if (exists('g:semanticEnableFileTypes'))
	if type(g:semanticEnableFileTypes) == type([])
		execute 'autocmd FileType ' . join(g:semanticEnableFileTypes, ',') . ' call s:enableHighlight()'
	elseif type(g:semanticEnableFileTypes) == type({})
		execute 'autocmd FileType ' . join(keys(g:semanticEnableFileTypes), ',') . ' call s:enableHighlight()'
		execute 'autocmd CursorHold ' . join(map(values(g:semanticEnableFileTypes), '"*." . v:val'), ',') . ' call s:semHighlight()'
	endif
endif

" Set defaults for colors
let s:semanticGUIColors = [ '#72d572', '#c5e1a5', '#e6ee9c', '#fff59d', '#ffe082', '#ffcc80', '#ffab91', '#bcaaa4', '#b0bec5', '#ffa726', '#ff8a65', '#f9bdbb', '#f9bdbb', '#f8bbd0', '#e1bee7', '#d1c4e9', '#ffe0b2', '#c5cae9', '#d0d9ff', '#b3e5fc', '#b2ebf2', '#b2dfdb', '#a3e9a4', '#dcedc8' , '#f0f4c3', '#ffb74d' ]
let s:semanticTermColors = range(20)

" The user can change the GUI/Term colors, but cannot directly access the list of colors we use
" If the user overrode the default in their vimrc, use that
let g:semanticGUIColors = exists('g:semanticGUIColors') ? g:semanticGUIColors : s:semanticGUIColors
let g:semanticTermColors = exists('g:semanticTermColors') ? g:semanticTermColors : s:semanticTermColors

" Allow the user to turn cache off
let g:semanticUseCache = exists('g:semanticUseCache') ? g:semanticUseCache : 1
let g:semanticPersistCache = exists('g:semanticPersistCache') ? g:semanticPersistCache : 1
let g:semanticPersistCacheLocation = exists('g:semanticPersistCacheLocation') ? g:semanticPersistCacheLocation : $HOME . '/.semantic-highlight-cache'

" Allow the user to override blacklists
let g:semanticEnableBlacklist = exists('g:semanticEnableBlacklist') ? g:semanticEnableBlacklist : 1

let s:blacklist = {}
if g:semanticEnableBlacklist
	let s:blacklist = blacklist#GetBlacklist()
endif

let s:containedinlist = containedinlist#GetContainedinlist()

let g:semanticUseBackground = 0
let s:hasBuiltColors = 0

command! SemanticHighlight call s:semHighlight()
command! SemanticHighlightRevert call s:disableHighlight()
command! SemanticHighlightToggle call s:toggleHighlight()
command! RebuildSemanticColors call s:buildColors()

function! s:readCache() abort
	if !filereadable(g:semanticPersistCacheLocation)
		return []
	endif

	let l:localCache = {}
	let s:cacheList = readfile(g:semanticPersistCacheLocation)
	for s:cacheListItem in s:cacheList
		let s:cacheListItemList = eval(s:cacheListItem)
		let l:localCache[s:cacheListItemList[0]] = s:cacheListItemList[1]
	endfor

	if exists("s:cacheListItem")
		unlet s:cacheListItem s:cacheList
	endif

	return l:localCache
endfunction

let s:cache = {}
let b:cache_defined = {}
if g:semanticPersistCache && filereadable(g:semanticPersistCacheLocation)
	let s:cache = s:readCache()
endif

autocmd VimLeave * call s:persistCache()

function! s:persistCache()
	let l:cacheList = []
	let l:mergedCache = extend(s:readCache(), s:cache)
	for [match,color] in items(l:mergedCache)
		call add(l:cacheList, string([match, color]))
		unlet match color
	endfor
	call writefile(l:cacheList, g:semanticPersistCacheLocation)
endfunction

function! s:getCachedColor(current_color, match)
	if !g:semanticUseCache
		return a:current_color
	endif

	if (has_key(s:cache, a:match))
		return s:cache[a:match]
	endif

	let s:cache[a:match] = a:current_color
	return a:current_color
endfunction

function! s:semHighlight()
	if s:hasBuiltColors == 0
		call s:buildColors()
	endif

	let cur_color = 0
	let color_len = len(s:semanticColors)

	let filetype = xolox#easytags#filetypes#canonicalize(&filetype)
	let ctags_filetypes = xolox#easytags#filetypes#find_ctags_aliases(filetype)
	let filetypes_pattern = printf('^\(%s\)$', join(map(ctags_filetypes, 'xolox#misc#escape#pattern(v:val)'), '\|'))
	let taglist = filter(taglist('.'), "get(v:val, 'language', '') =~? filetypes_pattern")

	let tagkinds = get(s:tagkinds, filetype, [])
	if !empty(tagkinds)
		let matches = filter(copy(taglist), 'v:val.kind =~ tagkinds')
		if matches != []
			for tag in matches
				if s:is_keyword_compatible(tag)
					execute 'syntax keyword _semantic' . s:getCachedColor(cur_color, tag.name) . ' ' . tag.name
					let cur_color = (cur_color + 1) % color_len
				endif
			endfor
		endif
	endif
endfunction

function! s:buildColors()
	if (g:semanticUseBackground)
		let type = 'bg'
	else
		let type = 'fg'
	endif
	if has('gui_running') || (exists('&guicolors') && &guicolors)
		let colorType = 'gui'
		" Update color list in case the user made any changes
		let s:semanticColors = g:semanticGUIColors
	else
		let colorType = 'cterm'
		" Update color list in case the user made any changes
		let s:semanticColors = g:semanticTermColors
	endif

	let semIndex = 0
	for semCol in s:semanticColors
		execute 'hi! def _semantic'.semIndex.' ' . colorType . type . '='.semCol
		let semIndex += 1
	endfor
	let s:hasBuiltColors = 1
endfunction

function! s:disableHighlight()
	let b:semanticOn = 0
	for key in range(len(s:semanticColors))
		execute 'syn clear _semantic'.key
	endfor

	let b:cache_defined = {}
endfunction

function! s:enableHighlight()
	let b:cache_defined = {}
	call s:semHighlight()
	let b:semanticOn = 1
endfunction

function! s:toggleHighlight()
	if (exists('b:semanticOn') && b:semanticOn == 1)
		call s:disableHighlight()
	else
		call s:semHighlight()
		let b:semanticOn = 1
	endif
endfunction

function! s:define_tagkind(filetype, tagkinds)
	let s:tagkinds[a:filetype] = a:tagkinds
endfunction

" Function taken from xolox/vim-easytags
function! s:is_keyword_compatible(tag)
	let name = get(a:tag, 'name', '')
	if !empty(name)
		if name =~ '^\k\+$' && len(name) <= 80
			return !has_key(s:invalid_keywords, name)
		endif
	endif
	return 0
endfunction

" Documented under :help E395
let s:invalid_keywords = {
	\ 'cchar': 1,
	\ 'conceal': 1,
	\ 'contained': 1,
	\ 'containedin': 1,
	\ 'contains': 1,
	\ 'nextgroup': 1,
	\ 'skipempty': 1,
	\ 'skipnl': 1,
	\ 'skipwhite': 1,
	\ 'transparent': 1,
	\ }

let s:tagkinds = {}

" Tagkind definitions

call s:define_tagkind('cpp', '[vm]')
call s:define_tagkind('javascript', '[pv]')
call s:define_tagkind('php', '[v]')
call s:define_tagkind('python', '[mv]')

