syntax clear

syn region dictDefWordnet matchgroup=Title start="^ From \zsWordNet" end="^ " contains=dictWNtype,dictWNlink,dictWNSynReg,dictWNEntry
syn region dictWNSynReg matchgroup=PreProc start='\[syn:' end='\]' contained containedin=dictDefWordnet contains=dictWNlink,dictWNConceal
syn region dictWNAntReg matchgroup=PreProc start='\[ant:' end='\]' contained containedin=dictDefWordnet contains=dictWNlink,dictWNConceal
syn region dictWNString start=/"/ skip=/\\\\\|\\"/ end=/"/ contained containedin=dictDefWordnet
syn match dictWNConceal '{' conceal contained containedin=dictWNSynReg,dictWNAntReg
syn match dictWNConceal '}' conceal contained containedin=dictWNSynReg,dictWNAntReg
syn match dictWNComma ',' contained containedin=dictWNSynReg,dictWNAntReg
syn match dictWNEntry  '^   \S.*$' contained containedin=dictDefWordnet
syn match dictWNType   '^     [a-z]\+$' contained containedin=dictDefWordnet
syn match dictWNNumber '^       [0-9]\+' contained containedin=dictDefWordnet

hi def link dictWNAntReg Identifier
hi def link dictWNSynReg Identifier
hi def link dictWNComma Normal
hi def link dictWNType Type
hi def link dictWNNumber Number
hi def link dictWNEntry Identifier
hi def link dictWNString String

syn region dictDefGcide matchgroup=Title start="^ From \zsThe Collaborative International Dictionary of English" end="^ " contains=dictGcidetype,dictGcidelink,dictGcideSynReg,dictGcideEntry
syn match dictGcideEntry  '^   \zs.\+\ze \\' contained containedin=dictDefGcide
syn region dictGcidePron2 matchgroup=Normal start=' (' end=')' contained  containedin=dictDefGcide keepend
syn region dictGcidePron  matchgroup=Normal start='\\' end='\\' contained containedin=dictDefGcide nextgroup=dictGcidePron2
syn region dictGcideType matchgroup=Normal start='\. (' end=')' contained  containedin=dictDefGcide keepend
syn match dictGcideNumber '^      [0-9]\+' contained containedin=dictDefGcide
syn match dictGcideConceal '{' conceal contained containedin=dictDefGcide
syn match dictGcideConceal '}' conceal contained containedin=dictDefGcide
syn region dictGcideLink matchgroup=Conceal start='{' end='}' contained containedin=dictDefGcide

hi def link dictGcideLink Identifier
hi def link dictGcideType Type
hi def link dictGcideNumber Number
hi def link dictGcideEntry Identifier
hi def link dictGcidePron Function
hi def link dictGcidePron2 Special
hi def link dictGcideConceal Conceal

syn region dictDefFD matchgroup=Title start="^ From \zs.* FreeDict Dictionary" end="^ " contains=dictFDEntry,dictFDPron,dictFDNum
syn match dictFDEntry '^   .\{-}\ze /' contained containedin=dictDefFD
syn match dictFDNum '^   [0-9]\+\. ' contained containedin=dictDefFD
syn region dictFDPron matchgroup=None start=' /' matchgroup=None end='/$' contained containedin=dictDefFD
" editor porta mão servidor slash
"
hi def link dictFDEntry Identifier
hi def link dictFDPron Special
hi def link dictFDNum Number
