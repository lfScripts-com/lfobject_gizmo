fx_version 'cerulean'
game 'gta5'
lua54 'yes'
version '2.1.0'
escrow_ignore {
	'client/gizmo.lua',
	'client/test.lua',
	'client/dataview.lua',
	'version.lua',
}

client_scripts {
	"client/gizmo.lua",
	'client/test.lua'
}

shared_scripts {
	'@ox_lib/init.lua'
}

files {
	'locales/*.json',
	'client/dataview.lua',
}

server_script 'version.lua'

dependencies {
	'ox_lib'
}
