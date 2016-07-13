import vibe.d;


void hello(HTTPServerRequest req, HTTPServerResponse res)
{
	res.writeBody("Hello, World!");
}

shared static this()
{
	ushort port = 8080;
	readOption("port|p", &port, "Port to bind");

	auto settings = new HTTPServerSettings;
	settings.port = port;
	settings.bindAddresses = ["0.0.0.0"];
	listenHTTP(settings, &hello);

	logInfo("Please open https://novaposhta-unofficial-bot.herokuapp.com/ in your browser.");
}