import vibe.d;
import std.stdio;
import std.array;
import std.algorithm;
import std.uuid: randomUUID;
import std.process: environment;


immutable string API_KEY;
immutable string BOT_KEY;


Json documentsTracking (string documentNumber, string phone = "380ХХХХХХХХХ")
{
	auto r = Json.emptyObject;
	r["apiKey"] = API_KEY;
	r["modelName"] = "TrackingDocument";
	r["calledMethod"] = "getStatusDocuments";
	r["methodProperties"] = Json.emptyObject;
	r["methodProperties"]["Documents"] = [Json(["DocumentNumber": Json(documentNumber), "Phone": Json(phone)])];
	r["methodProperties"]["Language"] = "UA";

	Json result;
	requestHTTP("http://testapi.novaposhta.ua/v2.0/en/documentsTracking/json/",
		(scope req) {
			req.method = HTTPMethod.POST;
			req.writeJsonBody(r);
		},
		(scope res) {
			result = res.readJson;
		}
	);
	return result;
}

auto getUsage () {
	auto help = "Це неофіційний бот для Нової Пошти\n"
		"зараз підтримується лише відстежування отримання\n"
		"\n"
		"/start - це повідомленя\n"
		"/track <номер накладної> - Відстежити отримання за номером накладної\n"
		"/help - це повідомленя";
	return help;
}

void webHook (HTTPServerRequest req, HTTPServerResponse res)
{
	res.writeVoidBody;
	res.finalize;

	logInfo("Request: " ~ req.json.toString);

	auto text = req.json["message"]["text"].get!string;
	auto resp = Json.emptyObject;
	resp["chat_id"] = req.json["message"]["chat"]["id"];
	auto cmd = text.split.array;
	switch(cmd[0]) {
		case "/track":
			logInfo("get track request");
			if (cmd.length < 2) {
				resp["text"] = "Будь ласка вкажіть номер накладної у форматі: /track <номер накладної>";
				break;
			}
			auto number = cmd[1];
			logInfo("with number: " ~ number);
			auto result = documentsTracking(number);
			logInfo("from NP got response: " ~ result.toString);
			resp["text"] = result["data"][0]["Status"].get!string ~ ": " ~ result["data"][0]["WarehouseRecipient"].get!string;
			logInfo("prepared: " ~ resp.toString);
			break;
		case "/start":
		case "/help":
			resp["text"] = getUsage;
			break;
		default:
			resp["text"] = "Sorry, I do not understand.";
	}

	requestHTTP("https://api.telegram.org/bot" ~ BOT_KEY ~ "/sendMessage",
		(scope req) {
			req.method = HTTPMethod.POST;
			req.writeJsonBody(resp);
		},
		(scope res) {
			logInfo("Response: %s", res.bodyReader.readAllUTF8);
		}
	);
}

shared static this ()
{
	ushort port = 8080;
	readOption("port|p", &port, "Port to bind");

	API_KEY = environment.get("NP_API_KEY");
	BOT_KEY = environment.get("TG_BOT_KEY");
	immutable string secretKey = randomUUID.toString;

	logInfo("API_KEY: " ~ API_KEY);
	logInfo("BOT_KEY: " ~ BOT_KEY);
	logInfo("secretKey: " ~ secretKey);

	auto settings = new HTTPServerSettings;
	settings.port = port;
	settings.bindAddresses = ["0.0.0.0"];

	auto router = new URLRouter;
	router.post("/hook/" ~ secretKey, &webHook);

	listenHTTP(settings, router);

	requestHTTP("https://api.telegram.org/bot" ~ BOT_KEY ~ "/setWebhook?url="
				"https://novaposhta-unofficial-bot.herokuapp.com/hook/" ~ secretKey,
		(scope req) {
			req.method = HTTPMethod.POST;
		},
		(scope res) {
			logInfo("Response: %s", res.bodyReader.readAllUTF8);
		}
	);

	logInfo("Please open https://novaposhta-unofficial-bot.herokuapp.com/ in your browser.");
}