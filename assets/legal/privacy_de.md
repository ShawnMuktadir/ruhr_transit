# Datenschutzerklärung

Stand: 22. November 2026

## Verantwortlicher

Md Muktadir, E-Mail: mmuktadir778@gmail.com. Die Postanschrift steht im Impressum.

Im Datenschutzrecht heißt diese Person "Verantwortlicher": Sie entscheidet, warum und wie in dieser App personenbezogene Daten verarbeitet werden.

## Überblick

RuhrTransit zeigt Abfahrten, Haltestellen und Verbindungen im Gebiet des Verkehrsverbunds Rhein-Ruhr (VRR) und in ganz Deutschland.

- Die App hat **kein Benutzerkonto**, **keine Werbung** und **keine Analyse oder Nachverfolgung (Tracking)**.
- Die App hat **keinen eigenen Server**. Ich als Entwickler erhalte keine Daten aus der App.
- Für Fahrpläne, Wetter und Karten verbindet sich die App direkt mit den unten genannten Diensten. Diese Dienste erhalten, was die App ihnen sendet.
- Alles andere bleibt auf Ihrem Gerät.

## Was die App an wen sendet

### Fahrplanauskunft des VRR

Für Fahrplanauskünfte verbindet sich die App mit der Fahrplanauskunft der Verkehrsverbund Rhein-Ruhr AöR (openservice.vrr.de). Sie sendet:

- **Was Sie in eine Suche eingeben**, für Haltestellen und bei "Von" und "Nach" auch für Adressen und Orte. Wenn Sie Ihre Wohnadresse eingeben, erhält der VRR diese.
- **Die Haltestellen, Adressen und Orte, die Sie wählen**, und die **Zeit** einer Verbindungssuche.
- **Ihren Standort für "Haltestellen in der Nähe"**: Die App liest Ihren Standort und sendet die Koordinaten, um Haltestellen im Umkreis von 1 km zu finden. Beim ersten Mal geschieht das erst, wenn Sie auf "Standort verwenden" tippen. Wenn Sie den Standortzugriff erlaubt haben, geschieht das bei jedem Öffnen von "Haltestellen in der Nähe".
- **Ihren Standort für "Aktuellen Standort als Start verwenden"** neben "Von" und für **"Weg zu ..."** in einer Verbindung: nur wenn Sie tippen. Die Koordinaten werden auf etwa 10 m gerundet. Der VRR nennt die Adresse dort, und die Verbindung wird von dieser Adresse aus geplant.
- **Erinnerungen** (nur Android): Wenn eine von Ihnen eingestellte Erinnerung fällig ist, fragt die App beim VRR die Verspätung dieser Fahrt ab. Sie sendet die Linie, die Fahrt und die Haltestelle. Das geschieht auch, wenn die App geschlossen ist.

### Bright Sky (Wetter)

Wenn Sie den Standortzugriff erlaubt haben, zeigt die App das Wetter an Ihrem Ort. Sie sendet Ihre Koordinaten, **auf etwa 1 km gerundet**, an Bright Sky (api.brightsky.dev), einen kostenlosen Dienst mit Daten des Deutschen Wetterdienstes. Das geschieht, wenn Sie den Bereich "Verbindung" öffnen, und erneut, wenn Sie nach 30 Minuten oder mehr in die App zurückkehren. Ohne Standortzugriff fragt die App nur, wenn Sie auf die Wetteranzeige tippen. Bright Sky veröffentlicht keine eigene Datenschutzerklärung. Informationen: https://brightsky.dev

### basemap.de (Karten)

Wenn eine Karte angezeigt wird, lädt die App die Kartenbilder für den sichtbaren Bereich von basemap.de, einem Dienst des Bundesamts für Kartographie und Geodäsie (BKG, sgx.geodatenzentrum.de). Das BKG erfährt, welcher Bereich angezeigt wird. Bei der Karte "Haltestellen in der Nähe" ist das ungefähr Ihr Standort. Datenschutzerklärung des BKG: https://www.bkg.bund.de/datenschutz

### Google Übersetzer (nur wenn Sie tippen)

Hinweise und Gründe für Verspätungen kommen vom VRR auf Deutsch. Wenn die App in einer anderen Sprache läuft und Sie auf "Übersetzen" tippen, öffnet die App den Text in Google Übersetzer, in der App Google Übersetzer oder in Ihrem Browser. Google erhält den Text des VRR, der nichts über Sie enthält. Google verarbeitet Daten möglicherweise auch außerhalb der EU. Datenschutzerklärung von Google: https://policies.google.com/privacy

### Ihre IP-Adresse

Wie bei jeder Internetverbindung sieht der Dienst, mit dem die App sich verbindet, Ihre **IP-Adresse**: der VRR, Bright Sky, das BKG und bei "Übersetzen" Google. Das kann die App nicht verhindern.

### Standort unter Android

Unter Android erhält die App Ihren Standort von den Google Play-Diensten auf Ihrem Telefon. Wie Google mit Standortdaten umgeht, hängt von den Standorteinstellungen Ihres Telefons und Ihres Google-Kontos ab. Die App selbst sendet Ihren Standort nur an die oben genannten Dienste.

## Wer bei diesen Diensten über die Daten entscheidet

Der VRR, Bright Sky, das BKG und Google verarbeiten die Daten, die sie erhalten, in eigener Verantwortung. Sie handeln nicht in meinem Auftrag. Es gelten ihre eigenen Datenschutzerklärungen.

## Daten auf Ihrem Gerät

Die App speichert Folgendes **nur auf Ihrem Gerät**:

- **Favoriten**: Haltestellen und gespeicherte Verbindungen, mit den Namen, die Sie vergeben. Eine gespeicherte Verbindung kann an einer Adresse beginnen oder enden. Wenn Sie eine Verbindung speichern, die an Ihrem aktuellen Standort beginnt, wird die Adresse in Ihrer Nähe mitgespeichert.
- **Suchverlauf**: die letzten 10 Haltestellen, Adressen und Orte, die Sie bei "Von" und "Nach" gewählt haben. Sie können ihn in der Haltestellenauswahl löschen, ganz oder einzeln.
- **Erinnerungen**: die Fahrt, die Haltestelle und die Zeit, bis die Fahrt abgefahren ist.
- **Gespeicherte Abfahrten**: die letzten Abfahrten von bis zu 10 Haltestellen, damit sie ohne Internet sichtbar bleiben, und die Daten des Startbildschirm-Widgets.
- **Kartenbilder**, die Sie angesehen haben, bis zu 100 MB, damit Karten schneller laden. Sie zeigen, welche Gegenden Sie angesehen haben.
- **Einstellungen**: Sprache, Darstellung, Verkehrsmittel und Ihr Anzeigename, wenn Sie einen eingeben.

Die App speichert Ihre Koordinaten nicht. Sie liest Ihren Standort nicht im Hintergrund.

Unter Android können diese Daten Teil der Sicherung Ihres Google-Kontos sein, wenn Sie die Sicherung in den Einstellungen Ihres Telefons eingeschaltet haben.

## Warum die App das darf (Rechtsgrundlagen)

- Suchen, Haltestellen und Zeiten an den VRR senden und Karten laden: Das ist nötig, um Ihnen die Auskunft zu geben, die Sie in der App anfragen (Art. 6 Abs. 1 lit. b DSGVO).
- Ihren Standort verwenden: Sie entscheiden darüber, indem Sie den Standortzugriff in den Einstellungen Ihres Telefons erlauben (Einwilligung, Art. 6 Abs. 1 lit. a DSGVO). Sie können sie jederzeit in den Einstellungen widerrufen. Ohne sie funktionieren alle Funktionen außer denen, die Ihren Standort brauchen.
- Wenn Sie mir eine E-Mail schreiben: Ich verwende Ihre Nachricht nur, um Ihnen zu antworten (Art. 6 Abs. 1 lit. b oder f DSGVO).

## Wie lange Daten gespeichert werden

- Ich als Entwickler erhalte keine Daten aus der App und speichere daher keine. E-Mails lösche ich, wenn ich sie nicht mehr brauche.
- Daten auf Ihrem Gerät bleiben, bis Sie sie in der App löschen, den Speicher der App leeren oder die App deinstallieren.
- Wie lange der VRR, Bright Sky, das BKG und Google Daten speichern, steht in ihren eigenen Datenschutzerklärungen.

## So löschen Sie Ihre Daten

- In der App: Favoriten und gespeicherte Verbindungen entfernen, den Suchverlauf in der Haltestellenauswahl löschen und Erinnerungen löschen.
- Android: Einstellungen, Apps, RuhrTransit, Speicher, "Speicherinhalt löschen". Das löscht alles, was die App gespeichert hat.
- iPhone: die App löschen.
- Standortnutzung beenden: den Standortzugriff für RuhrTransit in den Einstellungen Ihres Telefons ausschalten.

## Ihre Rechte

Nach der DSGVO haben Sie das Recht auf Auskunft, Berichtigung, Löschung, Einschränkung der Verarbeitung, Datenübertragbarkeit und Widerspruch. Eine Einwilligung können Sie jederzeit widerrufen. Sie können sich auch bei einer Datenschutz-Aufsichtsbehörde beschweren, zum Beispiel an Ihrem Wohnort.

Bitte beachten Sie: Ich habe aus der App keine Daten über Sie. Zu Daten, die der VRR, Bright Sky, das BKG oder Google erhalten haben, wenden Sie sich bitte an diese.

Kontakt: mmuktadir778@gmail.com

## Kinder

Die App richtet sich nicht an Kinder unter 16 Jahren. Sie erhebt nicht wissentlich Daten von Kindern.

## Änderungen

Ich passe diese Erklärung an, wenn sich die App ändert. Das Datum oben zeigt die letzte Änderung. Die aktuelle Fassung steht in der App unter Einstellungen, Rechtliches, und online.
