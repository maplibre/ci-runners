var DSP_CLOUDFLARE = NewDnsProvider("cloudflare");
var REG_NONE = NewRegistrar("none");

D("maplibre.org", REG_NONE,
	DnsProvider(DSP_CLOUDFLARE),
	DefaultTTL(1), // 1 = Cloudflare "Auto"
	CF_MANAGE_COMMENTS, // sync record comments
	A("@", "185.199.111.153"),
	A("@", "185.199.110.153"),
	A("@", "185.199.109.153"),
	A("@", "185.199.108.153"),
	A("code", "3.72.22.1", CF_COMMENT("Forgejo; not proxied so SSH and large pushes work")),
	// Amazon SES sends Forgejo mail from code.maplibre.org (opentofu/forgejo).
	CNAME("2vwgi43gxzdh5yu37m2hdkqmfyjdlxp6._domainkey.code", "2vwgi43gxzdh5yu37m2hdkqmfyjdlxp6.dkim.amazonses.com."),
	CNAME("zht7ux66m254mi4bpmfhponieuio4wjg._domainkey.code", "zht7ux66m254mi4bpmfhponieuio4wjg.dkim.amazonses.com."),
	CNAME("azfcxow5jraer4hifztbftxbf2pjg447._domainkey.code", "azfcxow5jraer4hifztbftxbf2pjg447.dkim.amazonses.com."),
	MX("bounce.code", 10, "feedback-smtp.eu-central-1.amazonses.com."),
	TXT("bounce.code", "v=spf1 include:amazonses.com ~all"),
	CNAME("8eb6edd74dff4d341a64a93f7faae9f7", "verify.bing.com."),
	CNAME("demotiles", "maplibre.github.io.", CF_PROXY_ON),
	CNAME("martin", "ec2-35-86-216-243.us-west-2.compute.amazonaws.com.", CF_PROXY_ON),
	CNAME("roadmap", "maplibre.github.io.", CF_PROXY_ON),
	CNAME("webgl.demo.maplibre-rs", "maplibre-rs-webgl.pages.dev.", CF_PROXY_ON),
	CNAME("webgl-multithreaded.demo.maplibre-rs", "maplibre-rs-demo-webgl-multithreaded.pages.dev.", CF_PROXY_ON),
	CNAME("webgpu.demo.maplibre-rs", "maplibre-rs-demo-webgpu.pages.dev.", CF_PROXY_ON),
	CNAME("www", "maplibre.github.io.", CF_PROXY_ON),
	MX("@", 10, "alt4.aspmx.l.google.com."),
	MX("@", 10, "alt3.aspmx.l.google.com."),
	MX("@", 5, "alt2.aspmx.l.google.com."),
	MX("@", 5, "alt1.aspmx.l.google.com."),
	MX("@", 1, "aspmx.l.google.com."),
	TXT("_atproto", "did=did:plc:o5hobfaa5j2nljmsa24dznrg", CF_COMMENT("BlueSky validation")),
	TXT("_github-challenge-maplibre-org", "ed7996934c", CF_COMMENT("GitHub Domain Verification")),
	TXT("_github-challenge-maplibre-org.www", "882a5598c8", CF_COMMENT("GitHub Domain Verification (www)")),
	TXT("_github-pages-challenge-maplibre", "b7690a734a8177856b9165d78d447c"),
	TXT("@", "google-site-verification=ikB5Ujs1UK7CyC0IIz0NlZwbXXsKcO4CIiHje1D-H2E"),
	TXT("@", "nk6lv256yw"),
	TXT("@", "ticket-1860"),
	TXT("@", "google-site-verification=1Cwhg8Mw_4iW_Mmz-iQClyyELef3jA41OtYw-d8Ku7o", CF_COMMENT("Google Workspace site verification 2023-12-05")),
	TXT("@", "google-gws-recovery-domain-verification=48367955", CF_COMMENT("Google Workspace 2023-12-05")),
	TXT("@", "google-site-verification=5rHOILlh98_JT89bIzx1yUMtm3N5-tozlDgdBUtVkTE"),
	TXT("@", "https://issues.sonatype.org/browse/OSSRH-68079"),
);

