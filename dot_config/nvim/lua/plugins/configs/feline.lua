local _feline, feline = pcall(require, “feline”)
if not _feline then
	return
end

local gruvbox = {
    fg = ‘#928374’,
    bg = ‘#1F2223’,
    black =‘#1B1B1B’,
    skyblue = ‘#458588’,
    cyan = ‘#83A597’,
    green = ‘#689D6A’,
    oceanblue = ‘#1D2021’,
    magenta = ‘#FB4934’,
    orange = ‘#FABD2F’,
    red = ‘#CC241D’,
    violet = ‘#B16286’,
    white = ‘#EBDBB2’,
    yellow = ‘#D79921’,
}

feline.setup({
	theme = gruvbox
})
