implement Sshd;

include "sys.m";
	sys: Sys;

include "draw.m";

include "dial.m";
	dial: Dial;

include "arg.m";

Sshd: module {
	init: fn(nil: ref Draw->Context, argv: list of string);
};

chatty: int = 0;
bsize: int = 256;
buf: array of byte;
str: string;
gap: int;

# Listen on a provided port for ssh connections and attempt to OOM clients
# Inspiration: https://nullprogram.com/blog/2019/03/22/
init(nil: ref Draw->Context, argv: list of string) {
	sys = load Sys Sys->PATH;
	dial = load Dial Dial->PATH;
	if(dial == nil)
		raise "load dial = nil";
	arg := load Arg Arg->PATH;
	if(arg == nil)
		raise "load arg = nil";

	buf = array[bsize] of byte;
	str = "uwu";
	port := 22;
	gap = 3000;

	arg->init(argv);
	arg->setusage("sshd [-D] [-p port] [-s string] [-d delay (ms)]");

	while((opt := arg->opt()) != 0) {
		case opt {
		'D' =>
			chatty++;
		'p' =>
			port = int arg->earg();
		's' =>
			str = arg->earg();
			if(len(str) >= 4)
				if(str[:4] == "SSH-")
					raise "string cannot begin with SSH-";
		'd' =>
			gap = int arg->earg();
		* =>
			arg->usage();
		}
	}

	addr := "tcp!*!" + string port;
	ac := dial->announce(addr);
	if(ac == nil)
		raise "could not announce to " + addr;

	# Fill buf
	j := 0;
	for(i := 0; i < bsize; i++) {
		if(j == len(str))
			j = 0;
		buf[i] = byte str[j];
		j++;
	}

	buf[bsize-2] = byte '\r';
	buf[bsize-1] = byte '\n';

	# Accept all connections forever
	for(;;) {
		lc := dial->listen(ac);
		if(lc == nil)
			raise "listen failed on " + addr;

		if(chatty)
			sys->print("Incoming: %s\n", dial->netinfo(lc).raddr);

		fd := dial->accept(lc);
		spawn handler(fd);
	}

	exit;
}

# Handle a connection ;; if we can't write, it's an error
handler(fd: ref Sys->FD) {
	for(;;) {
		sys->sleep(gap);
		n := sys->write(fd, buf, bsize);
		if(n != bsize)
			break;
		
		if(chatty)
			spawn log(sys->sprint("Wrote: %s", string buf));
	}
}

# No-return wrapper for spawn
log(s: string) {
	sys->print("%s\n", s);
}

