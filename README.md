# NetSwitch

Pannello compatto in stile Windows 11 per gestire le interfacce di rete, ancorato alla barra
delle applicazioni vicino all'orologio.

Disponibile anche per **macOS** (Apple Silicon), nella barra dei menu: vedi
[mac/README.md](mac/README.md). Sito e download: [netswit.ch](https://netswit.ch).

## Uso
Esegui `NetSwitch.exe` (richiede privilegi di amministratore: compare il prompt UAC).

- **Clic sinistro sull'icona** → apre/chiude il pannello (si chiude anche cliccando altrove o con Esc).
- **Clic destro sull'icona** → menu rapido: interfacce, configurazioni salvate, avvio automatico, esci.
- Rilanciare l'exe mentre è già attivo riapre il pannello.

Il pannello segue il tema chiaro/scuro e il colore d'accento di Windows e si posiziona sul lato
della barra delle applicazioni (in basso o in alto).

## Funzioni
- **Interfacce**: raggruppate in *Connesse* (pallino verde), *Non connesse* (attive ma senza
  collegamento: pallino ambra e motivo, es. "Cavo scollegato") e *Disattivate* (cerchio vuoto,
  scheda attenuata). Per ognuna: IP, modalità DHCP/Statico e interruttore
  per attivarle/disattivarle (chiede conferma prima di disattivare). Clic sulla scheda per i
  dettagli (gateway, DNS, MAC, velocità): clic su un valore = copia negli appunti.
- **Imposta IP**: formato `IP/prefisso` o `IP/subnetmask` (es. `192.168.1.10/24`), più indirizzi
  separati da virgola. Gateway e DNS facoltativi (se vuoti vengono rimossi). Si può precompilare
  da una configurazione e salvare al volo come nuova configurazione.
- **DHCP**: indirizzo e DNS automatici.
- **Configurazioni salvate**: crea, modifica, duplica, riordina, elimina; applicabili a qualsiasi
  interfaccia dal pannello o dal menu del tasto destro. File: `%APPDATA%\NetSwitch\configurazioni.xml`.
- **Avvia con Windows** (menu ⋯): attività pianificata con privilegi elevati, parte in background
  senza prompt UAC.

## Compilazione
Non serve installare nulla (usa il compilatore C# e WPF inclusi in Windows):

    powershell -ExecutionPolicy Bypass -File build.ps1

Diagnostica: con `NETSWITCH_DEBUG=1` viene scritto `%TEMP%\netswitch_debug.log`.

## Esclusione di responsabilità
NetSwitch è fornito "così com'è", senza garanzie di alcun tipo. Modifica la configurazione di rete
del computer: lo usi a tuo rischio. Lo sviluppatore non è responsabile di danni, perdite di dati o
interruzioni di connettività derivanti dal suo utilizzo.
