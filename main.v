module main

import os
import cli
import commands

const version = '0.3.0'

fn main() {
	mut app := cli.Command{
		name: 'vss'
		version: version
		description: 'static site generator'
		execute: fn (cmd cli.Command) ! {
			println(cmd.help_message())
		}
	}

	// add commands
	app.add_command(commands.new_build_cmd())
	app.add_command(commands.new_serve_cmd())

	app.setup()

	// run the app
	app.parse(os.args)
}
