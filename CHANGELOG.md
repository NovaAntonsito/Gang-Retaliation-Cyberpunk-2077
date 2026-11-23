# Changelog - Gang Retaliation

## [1.5.5] - 2026-11-22

### English

#### Fixed
- A decapitation that lands right after the kill, or on a Nemesis who is already down, now confirms the death for good: the Nemesis does not come back and the "For good this time" message shows. Thanks to **Aephiex** for finding the problem and writing the fix.
- Boss weapons stored in your stash now show in the ARSENAL (marked IN THE STASH; open and close the stash once to register them). Take them out to use them in Augment.
- Hunt zones no longer land underground: the hunt point is checked against the surface (a point with a floor or structure more than 6 m above it is discarded and another is picked; if the ground isn't loaded yet, it is checked again when you get within 200 m), and the pin and the target appear at surface level.
- The GANG RETALIATION map filter checkbox now actually controls the bounty search-zone circle: it used to share a marker variant with a lot of unrelated game mappins, so (un)checking it did nothing to the circle, and unchecking every box could still leave other mods' pins hidden.
- History and Gang History now list events newest first, with no redundant trailing "Now" line (the GANGS panel already shows the current day at the top).
- A disarmed Nemesis fleeing from you is no longer blocked by the raid "can't flee" rule, and a disarmed/dismembered Nemesis found hiding no longer gets dragged back into a pointless fight. A self-heal injector being misread as a weapon could cause the first of these; fixed too.
- NPCs that should quietly disappear after fleeing out of sight (not ones you actually fought) could fail to actually despawn; fixed.
- Raids near V now only target a gang that actually has a foothold in your current district - a Barghest raid in Dogtown can no longer come after, say, a Maelstrom Nemesis with no presence there.
- Vehicle ambushes no longer spawn a car somewhere with no real road (a rooftop, for instance) when there's no traffic nearby to anchor the spawn to - falls back to an on-foot ambush instead.
- Intel Shards picked up off a downed gang member could end up stuck in your inventory instead of vanishing on pickup like they should; a periodic check now clears out any that slip through.

#### Changed
- Contracts are paid on any takedown by you (knockout or kill). The old "make sure they don't come back" condition is gone. Boss contracts still need the Boss to fall inside their stronghold.

#### Added
- **Bounty Board.** New button under JOURNAL. Fixers put a price on Nemeses who know you; take them down meeting the contract to get paid, with bonuses for exploiting their weaknesses.
- Fixers send Bounty Board news by SMS (new setting **Bounty Board notices by SMS**, on by default; off shows a short on-screen notice).
- Bounty Board SMS now stay in your phone: they arrive in a **Bounty Board** thread inside the real fixer's contact (Padre, Regina Jones, Wakako Okada, Dakota Smith, Mr. Hands, Rogue, El Capitán). Fixers you haven't met yet write from a **Bounty Board** contact. The details of each contract are on the Bounty Board.
- **Search zone.** Accept a contract and the fixer marks a search zone of about 70-80 m around where the target was seen: a circle on your minimap and the journal job with its GPS route on the map. Walk into the circle and the target shows up with 2 or 3 escorts; walk away (over 250 m, out of combat) and they leave, coming back when you return. The zone goes away when the contract is paid, failed or runs out. Contracts accepted before this update get their zone too.
- **Boss contracts.** Rare contracts (about 12% a day, one at a time) on a gang's Boss, who must die **inside their stronghold**: taking them down anywhere else leaves the job open. The zone is a wide circle (400 m, 250 m once you have 50% intel on that gang) somewhere around the stronghold without giving it away, and it follows the stronghold if the gang moves. If you already located the stronghold there is no circle: it's on your map. Bosses no longer show up in regular contracts.
- Bounty Board contracts arrive as **offers**: open the contract and press **ACCEPT CONTRACT** (or F) to take it. Up to 3 accepted contracts and 3 pending offers at a time. Only accepted contracts pay: take down the target of an offer you never accepted and the contract is lost. Offers expire like contracts.
- Contracts also pay **XP** (Soldier 350, Lieutenant 650, Boss 1,000, +50 per escape, up to +250) and some **Street Cred**.
- Intel Shards also reveal a hidden trait of one of the gang's Nemeses, highest rank first.
- The scanner shows a Nemesis's traits in their own TRAITS section.
- Every Nemesis who goes down, knocked out or killed, now carries an Intel Shard.
- A rare surprise from Rogue: once in a while one of her contracts comes marked **SPECIAL**. Complete every optional objective on it and she has something for you.
- **History merged into the GANGS screen.** The standalone Gang Retaliation History add-on's screen is replaced by two new sub-tabs on the GANGS detail panel: **History** (a selected Nemesis's own events) and **Gang History** (every event tagged to their whole gang). If you had the old add-on installed, its log is migrated into this mod automatically the first time you load with this version - nothing to do by hand.
- History and Information now show a bounty badge on a Nemesis with an open contract; clicking it jumps straight to that contract in the Bounty Board.
- GANGS and Bounty Board each have a button next to their own title to jump straight to the other one.
- **Clear Log** debug button (CET overlay window, next to "Clear campaign"): permanently deletes the active campaign's history. Does not touch other campaigns' saved history.
- The CET overlay window title now shows the installed version.

### Español

#### Arreglado
- Una decapitación que llega justo después de la muerte, o sobre un Némesis que ya está caído, ahora confirma la muerte para siempre: el Némesis no vuelve y sale el mensaje de que cayó para siempre. Gracias a **Aephiex** por encontrar el problema y escribir el arreglo.
- Las armas de Jefe que guardas en el alijo ahora aparecen en el ARSENAL (marcadas EN EL ALIJO; abre y cierra el alijo una vez para registrarlas). Sácalas del alijo para usarlas en el Aumento.
- Las zonas de caza ya no quedan bajo tierra: el punto de caza se comprueba contra la superficie (si encima hay un piso o una estructura a más de 6 m, se descarta y se elige otro; si el suelo todavía no cargó, se vuelve a comprobar cuando estés a menos de 200 m), y el pin y el objetivo aparecen a nivel de superficie.
- La casilla del filtro de mapa GANG RETALIATION ahora sí controla el círculo de la zona de búsqueda de recompensas: antes compartía variante de marcador con muchísimos otros mappins ajenos al mod, así que (des)tildarla no le hacía nada al círculo, y destildar todas las casillas igual podía dejar ocultos pins de otros mods.
- Historial e Historial de Banda ahora listan los eventos de más nuevo a más viejo, sin la línea final redundante "Now" (el panel de GANGS ya muestra el día actual arriba).
- Un Némesis desarmado que huye de ti ya no queda bloqueado por la regla de "no puede huir" de las redadas, y un Némesis desarmado/desmembrado encontrado escondido ya no es arrastrado de vuelta a una pelea sin sentido. Un inyector de autocuración mal interpretado como arma podía causar lo primero; también arreglado.
- Los NPCs que deberían desaparecer en silencio tras huir de la vista (no los que de verdad peleaste) podían no llegar a despawnear; arreglado.
- Las redadas cerca de V ahora solo apuntan a una banda que de verdad tiene pie en tu distrito actual - una redada de Barghest en Dogtown ya no puede ir contra, por ejemplo, un Némesis de Maelstrom sin presencia ahí.
- Las emboscadas en vehículo ya no aparecen en un lugar sin camino real (una azotea, por ejemplo) cuando no hay tráfico cerca para anclar la aparición - en ese caso cae a una emboscada a pie.
- Los Shards de Intel recogidos de un pandillero caído podían quedar atascados en el inventario en vez de desaparecer al recogerlos como deberían; un chequeo periódico ahora retira los que se cuelan.

#### Cambiado
- Los contratos se cobran con cualquier derribo hecho por ti (noqueo o muerte). Se quitó la condición de "que no vuelva". Los contratos de Jefe siguen exigiendo que el Jefe caiga dentro de su guarida.

#### Añadido
- **Bounty Board.** Botón nuevo debajo de JOURNAL. Los fixers ponen precio a los Némesis que te conocen; elimínalos cumpliendo el contrato para cobrar, con bonos por aprovechar sus debilidades.
- Los fixers mandan las novedades del Bounty Board por SMS (nuevo ajuste **Avisos del Bounty Board por SMS**, activado por defecto; apagado muestra un aviso corto en pantalla).
- Los SMS del Bounty Board ahora quedan en el teléfono: llegan a un hilo **Bounty Board** dentro del contacto del fixer real (Padre, Regina Jones, Wakako Okada, Dakota Smith, Mr. Hands, Rogue, El Capitán). Los fixers que todavía no conoces escriben desde un contacto **Bounty Board**. Los detalles de cada contrato están en el Bounty Board.
- **Zona de búsqueda.** Acepta un contrato y el fixer te marca una zona de búsqueda de unos 70-80 m alrededor de donde vieron al objetivo: un círculo en el minimapa y el encargo del diario con su ruta de GPS en el mapa. Entra al círculo y el objetivo aparece con 2 o 3 escoltas; si te alejas (más de 250 m, fuera de combate) se van, y vuelven cuando regresas. La zona desaparece al cobrar, fallar o vencer el contrato. Los contratos aceptados antes de esta versión también reciben su zona.
- **Contratos de Jefe.** Contratos raros (cerca de un 12 % al día, uno a la vez) sobre el Jefe de una banda, que tiene que morir **dentro de su guarida**: si cae en otro sitio, el contrato sigue abierto. La zona es un círculo amplio (400 m, 250 m cuando tienes 50 % de intel de esa banda) en algún punto alrededor de la guarida sin revelarla, y sigue a la guarida si la banda se muda. Si ya localizaste la guarida no hay círculo: está en tu mapa. Los Jefes ya no salen en los contratos normales.
- Los contratos del Bounty Board llegan como **ofertas**: abre el contrato y pulsa **ACEPTAR CONTRATO** (o F) para tomarlo. Hasta 3 contratos aceptados y 3 ofertas pendientes a la vez. Solo cobran los contratos aceptados: si eliminas al objetivo de una oferta que no aceptaste, pierdes el contrato. Las ofertas vencen igual que los contratos.
- Los contratos también dan **XP** (Soldado 350, Teniente 650, Jefe 1.000, +50 por escape, hasta +250) y algo de **Street Cred**.
- Los Intel Shards también revelan un rasgo oculto de uno de los Némesis de la banda, empezando por el de mayor rango.
- El escáner muestra los rasgos del Némesis en su propia sección RASGOS.
- Todo Némesis que cae, noqueado o muerto, ahora lleva un Shard de intel.
- Una rara sorpresa de Rogue: de vez en cuando uno de sus contratos viene marcado como **ESPECIAL**. Completa todos los opcionales y ella tiene algo para ti.
- **Historial fusionado a la pantalla GANGS.** La pantalla del add-on independiente Gang Retaliation History se reemplaza por dos pestañas nuevas en el panel de detalle de GANGS: **Historial** (los eventos propios del Némesis seleccionado) y **Historial de Banda** (todo evento marcado con toda su banda). Si tenías el add-on viejo instalado, su registro se migra a este mod automáticamente la primera vez que cargues con esta versión - no hay que hacer nada a mano.
- Historial e Información ahora muestran una insignia de recompensa en un Némesis con contrato abierto; al hacerle clic se salta directo a ese contrato en el Bounty Board.
- GANGS y Bounty Board tienen cada uno un botón junto a su propio título para saltar directo al otro.
- Botón de debug **Clear Log** (ventana de CET, junto a "Clear campaign"): borra permanentemente el historial de la campaña activa. No toca el historial guardado de otras campañas.
- El título de la ventana de CET ahora muestra la versión instalada.

## [1.4.10] - 2026-11-19

### English

#### Changed
- **Nemesis detail card now scrolls.** A nemesis with a lot of traits no longer spills past the card's bottom edge - the card scrolls (mouse wheel, gamepad, or a draggable bar) below the name and title.
- **Fallen roster improvements.** Fallen cards are now tall enough to show the cause of death without it running past the card. Click any fallen nemesis to see their full info in the side panel, same as a living one. The "+N" count is now a button that expands the full fallen list with a horizontal scrollbar.

### Español

#### Cambiado
- **La ficha de un Némesis ahora tiene scroll.** Un Némesis con muchos rasgos ya no se sale por debajo de la ficha - ahora se puede desplazar (rueda del mouse, mando o una barra arrastrable) debajo del nombre y el título.
- **Mejoras en los caídos.** Las fichas de caídos ahora son más altas para que la causa de muerte no se salga de la ficha. Hacé clic en cualquier caído para ver su información completa en el panel lateral, igual que uno vivo. El contador "+N" ahora es un botón que despliega la lista completa de caídos con una barra de desplazamiento horizontal.

Thanks to **RedFalcon** for all of this work. / Gracias a **RedFalcon** por todo este trabajo.

## [1.4.9] - 2026-11-18

### English

#### Changed
- **Intel Shards.** Knock out a gang member and his body carries a gang-branded **Intel Shard**. Loot it and the "Extracting intel" bar fills up and gives you the same intel as before (common +5%, Soldier +10%, Lieutenant +25%, Boss +50%). Kill him before you loot it and the shard is destroyed. This replaces the old "press 1" extraction and its map marker.
- **Takedowns count.** Grabs and finishers now go through gang detection like any other hit: a non-lethal takedown can give a shard or create a Nemesis.
- **Knocked out can mean Nemesis.** A gang member you leave unconscious can become a Nemesis (new setting **Knockout promotion chance**, 40% by default). He shows up 1 to 2 days later. Gangers who never spotted V (stealth takedowns, barrel kills, blind quickhacks) don't count.
- **Finishing a Nemesis off.** Decapitation is always permanent, even if it lands a moment after the kill. Losing another limb is not: that Nemesis comes back with chrome.
- **Map filter renamed.** The STRONGHOLDS checkbox is now **GANG RETALIATION**.
- **More names.** Every gang has around 40 to 50 names and handles instead of 12 to 16 (from the Expanded Names lists).
- **Nemesis marker by rank.** The marker over a Nemesis's head is white, red or gold for Soldier, Lieutenant or Boss.
- New messages for Nemeses who come back after being knocked out or dismembered.
- The installed version shows as the last row in Mod Settings.

### Español

#### Cambiado
- **Shards de intel.** Deja inconsciente a un pandillero y su cuerpo lleva un **Shard de intel** de su banda. Recógelo y la barra "Extrayendo información" se llena y te da la misma intel que antes (común +5 %, Soldado +10 %, Teniente +25 %, Jefe +50 %). Si lo matas antes de recogerlo, el shard se destruye. Reemplaza a la extracción con "1" y a su marcador en el mapa.
- **Los derribos cuentan.** Los agarres y remates pasan por la detección de bandas como cualquier golpe: un derribo no letal puede dar un shard o crear un Némesis.
- **Un noqueado puede volverse Némesis.** Un pandillero que dejas inconsciente puede volverse Némesis (nuevo ajuste **Probabilidad de ascenso por derribo**, 40 % por defecto). Aparece 1 o 2 días después. No cuentan los que nunca vieron a V (derribos sigilosos, barriles, hackeos a ciegas).
- **Rematar a un Némesis.** La decapitación siempre es definitiva, aunque llegue un instante después de la muerte. Perder otro miembro no: ese Némesis vuelve con implantes.
- **Filtro del mapa renombrado.** La casilla GUARIDAS ahora es **GANG RETALIATION**.
- **Más nombres.** Cada banda tiene entre 40 y 50 nombres y apodos en vez de 12 a 16 (de las listas de Expanded Names).
- **Marcador de Némesis por rango.** El marcador sobre la cabeza de un Némesis es blanco, rojo o dorado según sea Soldado, Teniente o Jefe.
- Mensajes nuevos para los Némesis que vuelven después de quedar noqueados o desmembrados.
- La versión instalada aparece como última fila en Mod Settings.

Thanks to **RedFalcon** for all of this work. / Gracias a **RedFalcon** por todo este trabajo.

## [1.4.8] - 2026-11-17

### English

#### Changed
- **Map filter renamed.** The STRONGHOLDS checkbox is now **GANG RETALIATION** and controls both strongholds and intel markers.

#### Fixed
- **Intel markers.** Knocked-out gang members you can extract data from no longer use the game's "cyberpsycho" skull marker; they share the hidden marker variant strongholds use, with the `codex_glossary` icon. Hovering one shows "{gang} intel target" and a short description. The marker is now restored after loading a save (the extract prompt already survived a reload; the map marker did not).

### Español

#### Cambiado
- **Filtro del mapa renombrado.** La casilla GUARIDAS ahora es **GANG RETALIATION** y controla tanto las guaridas como los objetivos de intel.

#### Arreglado
- **Objetivos de intel.** Los pandilleros inconscientes de los que se puede extraer datos ya no usan el marcador de calavera "ciberpsicópata" del juego; comparten la variante de marcador oculta de las guaridas, con el ícono `codex_glossary`. Al pasar el cursor se muestra "Objetivo de intel de {gang}" y una breve descripción. El marcador ahora se restaura al cargar una partida (el aviso de extracción ya sobrevivía a una recarga; el marcador del mapa no).

Thanks to **RedFalcon** for this work.

## [1.4.7] - 2026-11-17

### English

#### Fixed
- **Crash cycling map filters with Q/E.** The filter code called `GetScriptData()` on marker widgets the game had already freed.

#### Added
- **Stronghold map marker.** Strongholds use their own marker variant (`CPO_PingDoorVariant`), so the game filters them itself; the old hide/show/replay code was removed. Compatible with Map Icons Framework.
- **Stronghold map tooltip.** Title "Stronghold ({gang})", description, and a gang banner image at the bottom (new `GangRetaliationBanners.archive`).
- **Setting "Stronghold map banner"** (on by default) to show or hide the banner.

### Español

#### Arreglado
- **Crash al cambiar de filtro de mapa con Q/E.** El código del filtro llamaba a `GetScriptData()` sobre widgets de marcador que el juego ya había liberado.

#### Añadido
- **Marcador de guarida en el mapa.** Las guaridas usan su propia variante de marcador (`CPO_PingDoorVariant`), así que el juego las filtra por sí mismo; se eliminó el código anterior de ocultar/mostrar/repetir. Compatible con Map Icons Framework.
- **Tooltip de guarida en el mapa.** Título "Guarida ({gang})", descripción, e imagen del banner de la pandilla al final (nuevo `GangRetaliationBanners.archive`).
- **Ajuste "Banner de guaridas en el mapa"** (activado por defecto) para mostrar u ocultar el banner.

Thanks to **RedFalcon** for this work.

## [1.4.6] - 2026-11-16

### English

#### Fixed
- **Crash on the map.** The STRONGHOLDS filter could read a map marker the game had already removed.
- **STRONGHOLDS filter.** With STRONGHOLDS as the only checked box, the map shows only strongholds
  (before, they stayed hidden). With no box checked, the map shows everything, strongholds included.

Thanks to **RedFalcon** for finding the fix and writing the code for it.

### Español

#### Arreglado
- **Crash en el mapa.** El filtro GUARIDAS podía leer un marcador del mapa que el juego ya había
  borrado.
- **Filtro GUARIDAS.** Con GUARIDAS como única casilla marcada, el mapa muestra solo las guaridas
  (antes quedaban ocultas). Sin ninguna casilla marcada, el mapa muestra todo, guaridas incluidas.

Gracias a **RedFalcon** por encontrar el arreglo y escribir el código.

## [1.4.5] - 2026-11-16

### English

#### Added
- **Intel.** Knock a ganger out and press **1** ("Extract data"): an "Extracting intel" bar appears and
  fills in 3 seconds. Stay close or it is cancelled. Each extraction adds intel on that gang: common
  ganger +5%, Soldier +10%, Lieutenant +25%, Boss +50%. Common gangers can be extracted at most once
  per fight. A Nemesis brought below his flee line may, on a coin flip, fall unconscious instead of
  running away (only if he is not the last one standing). Knocked-out gangers you can extract from
  get a marker over the body, also on the minimap.
- **Intel bar.** NEMESIS → GANGS shows the intel you have on each gang, and "STRONGHOLD LOCATED" at 100%.
- **Gang Retaliation History integration.** With RedFalcon's add-on installed, the NEMESIS screen
  gets a HISTORY tab (click it, or TAB from ARSENAL). Add-ons can also open the NEMESIS screen on a
  given view (`GRMenuData.OpenView` / `RequestView`).

#### Changed
- **Strongholds move.** Each gang picks its stronghold among the places where the game already puts
  its gangers (organized crime activities first, then reported crimes), away from missions, safe
  spots, V and other strongholds. Take it and the gang moves somewhere else, and your intel on it
  drops back to 0. Voodoo Boys and Barghest keep their fixed stronghold.
- **Strongholds are hidden until you find them.** A gang's stronghold only shows on the map once you
  have 100% intel on that gang, or after you reach or take it. This also applies to existing saves.
- **New stronghold icon** on the map, minimap and world marker, with its own title
  ("Stronghold (gang)") instead of the NCPD one.
- **STRONGHOLDS map filter.** A new checkbox in the map's custom filter shows or hides strongholds,
  on by default. Strongholds no longer disappear when the NCPD scanner filter is off.
- **Nemeses are immune to traffic.** A car V is not driving (traffic, police, allies, a driverless
  car) no longer hurts or kills a Nemesis, including the fall right after the hit. Running one over
  with V's own car still counts.

#### Fixed
- **Stronghold guards no longer float or ignore V.** The stronghold now fills when V is about 70 m
  away instead of 120 m, each guard waits for solid ground and appears out of V's sight, and guards
  are awake and able to spot V from the start.
- **Invincible Nemeses.** A Nemesis who came from a mission ganger could keep that ganger's
  god mode (took no damage, or could not die). The mod now removes it when it spawns.
- **Enemies no longer end up inside buildings.** Fleeing Nemeses and leftover gangers walking away
  only move to a reachable spot on the street, on the same floor and out of V's sight. If there is
  none, they stay where they are.

### Español

#### Nuevo
- **Intel.** Deja inconsciente a un pandillero y pulsa **1** ("Extraer datos"): aparece la barra "Extrayendo información"
  y se llena en 3 segundos. Si te alejas, se cancela. Cada extracción suma intel de esa banda:
  pandillero común +5 %, Soldado +10 %, Teniente +25 %, Jefe +50 %. A los comunes se les puede
  extraer como mucho a uno por pelea. Un Némesis que baja de su línea de huida puede, a cara o cruz,
  caer inconsciente en vez de huir (solo si no es el último en pie). Los caídos a los que puedes
  extraer datos llevan un marcador sobre el cuerpo, también en el minimapa.
- **Barra de intel.** NÉMESIS → BANDAS muestra la intel que tienes de cada banda, y "GUARIDA
  LOCALIZADA" al 100 %.
- **Integración con Gang Retaliation History.** Con el add-on de RedFalcon instalado, la pantalla
  NÉMESIS tiene una pestaña HISTORIAL (clic, o TAB desde ARSENAL). Los add-ons también pueden abrir
  la pantalla NÉMESIS en una vista concreta (`GRMenuData.OpenView` / `RequestView`).

#### Cambiado
- **Las guaridas se mudan.** Cada banda elige su guarida entre los lugares donde el juego ya pone a
  sus pandilleros (primero actividades de crimen organizado, después crímenes denunciados), lejos de
  misiones, lugares seguros, V y otras guaridas. Si la tomas, la banda se muda a otro lado y tu intel
  sobre ella vuelve a 0. Voodoo Boys y Barghest mantienen su guarida fija.
- **Las guaridas están ocultas hasta que las encuentras.** La guarida de una banda solo sale en el
  mapa con su intel al 100 %, o después de llegar a ella o tomarla. También en partidas existentes.
- **Ícono nuevo de guarida** en el mapa, el minimapa y el marcador del mundo, con título propio
  ("Guarida (banda)") en vez del de la NCPD.
- **Filtro GUARIDAS en el mapa.** Una casilla nueva en el filtro personalizado del mapa muestra u
  oculta las guaridas, prendida por defecto. Las guaridas ya no desaparecen al apagar el filtro del
  escáner NCPD.
- **Los Némesis son inmunes al tráfico.** Un auto que no maneja V (tráfico, policía, aliados, un
  auto sin conductor) ya no hiere ni mata a un Némesis, tampoco con la caída justo después del golpe.
  Atropellarlo con el auto de V sigue contando.

#### Arreglado
- **Los guardias de las guaridas ya no flotan ni ignoran a V.** La guarida se llena cuando V está a
  unos 70 m en vez de 120 m, cada guardia espera a tener suelo firme y aparece fuera de la vista de
  V, y los guardias están despiertos y pueden detectar a V desde el principio.
- **Némesis invencibles.** Un Némesis que salió de un pandillero de misión podía heredar su modo
  dios (no recibía daño o no podía morir). Ahora el mod se lo quita al aparecer.
- **Los enemigos ya no quedan dentro de edificios.** Los Némesis que huyen y los pandilleros que se
  van al terminar un encuentro solo se mueven a un punto alcanzable en la calle, en el mismo piso y
  fuera de la vista de V. Si no hay ninguno, se quedan donde están.

## [1.4.0] - 2026-11-13

### English

#### Added
- **Gang strongholds (beta).** The locations may still change in future versions. Each gang now has a fixed stronghold in its own part of the city (the
  Barghest one is in Dogtown and needs Phantom Liberty). While the gang has at least one living
  Nemesis, its stronghold is on the map from the start: they all live there, the Boss in the middle,
  with guards around them (more for each living Lieutenant). Get close and they are at their posts.
  Kill them all and the stronghold falls and leaves the map. It comes back when the gang has
  Nemeses again.
- **Unique Boss weapons.** Every gang has its own signature weapon, and each Boss carries a copy with
  his name on it ("Joaquín's Overture"). It has an elemental bonus (electric, thermal or chemical,
  tied to the Boss's traits) that grows each time the Boss escapes you. Kill the Boss and the weapon
  is yours, scaled to V's level, and its elemental damage shows in the inventory tooltip. Scan a
  Boss to see his weapon in his detail panel.
- **ARSENAL view.** The NEMESIS screen has a third view (TAB): your Boss weapons, gang by gang, with
  their icon, element, bonus and the Boss you took them from.
- **Augment.** Fuse a copy into your gang weapon: the copy is destroyed, you choose which element
  stays, the bonus becomes the higher one x1.10 (max 60%) and the weapon gains a level (I to V,
  +5% damage each).

#### Changed
- **Barghest raids in Dogtown.** In Dogtown the NCPD does not raid: Barghest soldiers do. They hunt
  Nemeses of other gangs, with their own messages and no NCPD bounty SMS.
- **Bosses no longer ambush V.** They have better things to do. You still meet them in gigs,
  reinforcements, raids and their strongholds.

#### Fixed
- **Loading a save no longer starts a new campaign.** Sometimes the first load after launching the
  game created a new, empty campaign instead of continuing yours. Your saved campaign was never lost.
- **Drones and mechs no longer become Nemeses.** A drone, mech or robot that survived a fight could
  be promoted and later come back as a "Nemesis". Machines are now never promoted, and machine
  Nemeses saved by an older version are removed from the campaign when it loads.
- **No more ambushes underwater.** Ambushes no longer start while V is swimming or diving.
- **No more ambushes on top of a mission.** Ambushes no longer start within 150 m of the objective
  of the tracked job. Gang skirmishes follow the same rules (no swimming, no mission objective nearby).

### Español

#### Nuevo
- **Guaridas de bandas (beta).** Las ubicaciones todavía pueden cambiar en próximas versiones. Cada banda tiene ahora una guarida fija en su zona de la ciudad (la de
  Barghest está en Dogtown y necesita Phantom Liberty). Mientras la banda tenga al menos un Némesis
  vivo, su guarida aparece en el mapa desde el principio: todos viven ahí, el Jefe en el centro, con
  guardias alrededor (más por cada Teniente vivo). Al acercarte están en sus puestos. Si los matás a
  todos, la guarida cae y sale del mapa. Vuelve cuando la banda tiene Némesis otra vez.
- **Armas únicas de Jefe.** Cada banda tiene su arma propia y cada Jefe lleva una copia con su
  nombre ("Overture de Joaquín"). Tiene un bono elemental (eléctrico, térmico o químico, según los
  rasgos del Jefe) que sube cada vez que se te escapa. Si lo matás, el arma es tuya, al nivel de V.
  Su daño elemental aparece en el tooltip del inventario. Escaneá a un Jefe para ver su arma en su
  panel.
- **Vista ARSENAL.** La pantalla NÉMESIS tiene una tercera vista (TAB): tus armas de Jefe, banda por
  banda, con su ícono, elemento, bono y el Jefe al que se la sacaste.
- **Aumento.** Fusioná una copia con el arma de tu banda: la copia se destruye, elegís qué elemento
  queda, el bono pasa a ser el más alto x1,10 (tope 60 %) y el arma sube un nivel (de I a V, +5 % de
  daño cada uno).

#### Cambiado
- **Redadas de Barghest en Dogtown.** En Dogtown no hace redadas la NCPD sino soldados de Barghest.
  Cazan Némesis de otras bandas, con avisos propios y sin el SMS de recompensa de la NCPD.
- **Los Jefes ya no emboscan a V.** Tienen mejores cosas que hacer. Los seguís cruzando en gigs,
  refuerzos, redadas y en sus guaridas.

#### Arreglado
- **Cargar una partida ya no empieza una campaña nueva.** A veces la primera carga después de abrir
  el juego creaba una campaña nueva y vacía en vez de seguir la tuya. La campaña guardada nunca se
  perdía.
- **Los drones y los mechs ya no se vuelven Némesis.** Un drone, mech o robot que sobrevivía a una
  pelea podía ascender y volver después como "Némesis". Ahora las máquinas nunca ascienden, y los
  Némesis-máquina guardados por una versión anterior se borran de la campaña al cargarla.
- **No más emboscadas bajo el agua.** Las emboscadas ya no empiezan mientras V nada o bucea.
- **No más emboscadas encima de una misión.** Las emboscadas ya no empiezan a menos de 150 m del
  objetivo del trabajo que V está siguiendo. Las escaramuzas entre bandas siguen las mismas reglas
  (ni nadando ni cerca del objetivo de una misión).

## [1.3.4] - 2026-11-10

### English

#### Fixed
- **Fleeing gangers now really get away.** Before, a ganger from the world who fled turned back to
  fight after 30 m and V almost always killed them, so nobody escaped. Now they run in panic the way
  civilians do and keep running. Once V loses sight of them, or they are still alive when the fight
  ends, they become a Nemesis. If V catches up and shoots them, they fight again.
- **No more escapes in plain sight.** An ambush escort used to count as escaped after 25 s even if V
  was looking at them from 10 m away. Now they escape after 3 s out of V's sight and more than 25 m
  away, or after passing 50 m. If they can't break line of sight in 60 s, they turn and fight.
- **A fight that ended while someone was running no longer erases the escape.** If they came back
  to fight and survived, they used to be forgotten. Now they still count as fled.
- **They start running right away.** Before, the escape waited up to 1 s, and V could finish them
  off first.
- **Ambush escorts no longer get pulled back into the fight while fleeing.** The check that wakes up
  passive ambushers was treating a fleeing escort as passive and sending them back at V.
- **"Last one standing" really means last.** Before, only gangers that had shot or been shot counted,
  so one could flee while friends were still arriving. Now the enemies V is tracking count too.
- **Nobody vanishes in front of V anymore.** When an ambush, NCPD raid or gang skirmish ended,
  everyone it had spawned (survivors, bodies and the ambush car) was deleted at once, even in plain
  sight, and a fleeing escort could blink out mid-run. Now survivors stop fighting and walk away,
  and each one is removed only when V isn't looking: survivors out of sight past 30 m (or 80 m
  anywhere), bodies out of sight, and the car out of sight and never while V is driving it.
  A Nemesis killed while walking away still counts as killed.
- **Panic escape.** When the last one standing flees, the game's own panic reaction takes over, with
  a higher priority than combat, so they bolt in plain sight instead of turning around to fight
  again or blinking across the street in front of V. A Nemesis's icon and boss bar disappear right
  away. They count as fled and come back as a Nemesis.
- **A far-off or idle enemy no longer blocks the escape.** The "last one standing" check counted any
  hostile V had tracked, even one far away or not fighting, so nobody fled. Now only enemies in
  combat within 40 m count.
- **Indirect kills now count for V.** If V blew up a car with a Nemesis inside (shooting it until it
  explodes or with the self-destruct quickhack) or took them down from a grab (lethal or not), the
  mod said "nobody knows who did it" and the gang lost no strength. Those kills left no hit from V
  to read, so the mod now also checks who the game itself blames for the death.
- **A Nemesis who just escaped no longer ambushes right away.** They wait at least 1 game day after
  escaping V before their next ambush, so they have time to grow. Other Nemeses can still ambush
  in the meantime. Saves from older versions are not affected until the next escape.

### Español

#### Arreglado
- **Los pandilleros que huyen ahora escapan de verdad.** Antes, un pandillero del mundo que huía
  volvía a pelear a los 30 m y V casi siempre lo mataba, así que nadie escapaba. Ahora corre en
  pánico como los civiles y sigue corriendo. Cuando V lo pierde de vista, o si sigue vivo al terminar
  el combate, pasa a ser Némesis. Si V lo alcanza y le dispara, vuelve a pelear.
- **Ya no escapan a la vista.** Un escolta de emboscada contaba como escapado a los 25 s aunque V lo
  estuviera mirando a 10 m. Ahora escapa tras 3 s fuera de la vista de V y a más de 25 m, o al pasar
  50 m. Si en 60 s no logra perderse de vista, se da vuelta y pelea.
- **Si el combate terminaba mientras alguien corría, se perdía su huida.** Si después volvía a
  pelear y sobrevivía, se olvidaba. Ahora sigue contando como huido.
- **Empiezan a correr enseguida.** Antes la huida esperaba hasta 1 s y V podía rematarlo antes.
- **Las escoltas de emboscada ya no vuelven a la pelea mientras huyen.** El control que despierta a
  los emboscados pasivos tomaba como pasivo al que huía y lo mandaba de nuevo contra V.
- **"El último en pie" es de verdad el último.** Antes solo contaban los que habían disparado o
  recibido un tiro, así que uno podía huir con compañeros todavía llegando. Ahora también cuentan
  los enemigos que V tiene detectados.
- **Ya nadie desaparece delante de V.** Al terminar una emboscada, una redada de la NCPD o una
  escaramuza entre bandas, se borraba de golpe todo lo que había generado (sobrevivientes, cadáveres
  y el auto de la emboscada), aunque V lo estuviera mirando, y un escolta que huía podía esfumarse
  en plena carrera. Ahora los sobrevivientes dejan de pelear y se van caminando, y cada uno se borra
  solo cuando V no lo mira: los vivos fuera de la vista a más de 30 m (o a más de 80 m), los
  cadáveres fuera de la vista, y el auto fuera de la vista y nunca con V manejándolo. Un Némesis
  que muere mientras se va sigue contando como muerto.
- **Huida en pánico.** Cuando el último en pie huye, toma el control la reacción de pánico del propio
  juego, con más prioridad que el combate. Así sale corriendo a la vista en vez de darse vuelta a
  pelear de nuevo o teletransportarse al otro lado de la calle delante de V. El ícono y la barra de
  jefe de un Némesis se van enseguida. Cuenta como huido y vuelve como Némesis.
- **Un enemigo lejano o quieto ya no frena la huida.** El control de "último en pie" contaba a
  cualquier hostil que V tuviera detectado, aunque estuviera lejos o sin pelear, y nadie huía. Ahora
  solo cuentan los enemigos en combate a menos de 40 m.
- **Las muertes indirectas ahora cuentan para V.** Si V volaba un auto con un Némesis adentro (a
  tiros hasta que explota o con el hackeo de autodestrucción) o lo derribaba después de agarrarlo
  (letal o no), el mod decía "nadie sabe quién fue" y la banda no perdía fuerza. Esas muertes no
  dejaban ningún golpe de V para leer, así que ahora el mod también mira a quién culpa el propio
  juego por la muerte.
- **Un Némesis que acaba de escapar ya no embosca enseguida.** Espera al menos 1 día de juego
  después de escapar de V antes de su próxima emboscada, así tiene tiempo de crecer. Mientras
  tanto pueden emboscar otros Némesis. Las partidas de versiones anteriores no cambian hasta el
  próximo escape.

## [1.3.3] - 2026-11-03

### English

#### Added
- **They Will Remember integration (optional).** When a TWR vengeance squad of a gang with a living
  Nemesis fights V, that Nemesis may join and lead it (same chance as gig reinforcements). TWR's
  grudge (gang hostile, recent kills) raises the ambush chance, up to x2.
  - **Vengeance warning:** when TWR picks a gang to strike back, that gang's Boss or Lieutenant
    Nemesis who knows V texts V first (new messages in the "Unknown number" thread).
  - **Money doesn't buy a Nemesis:** if V pays TWR's redemption to a gang, TWR forgets, but its
    Boss or Lieutenant Nemesis turns it down by text. Their ambushes drop to half for 3 game days.
- **Drug Dealer integration (optional).** Gang Retaliation's ambushes, raids and skirmishes wait while a
  Drug Dealer job has enemies alive. A Nemesis may show up with the gang raiding your business or
  defending its turf. Your dealer rank raises the ambush chance (up to x1.48). Your Drug Dealer
  soldiers never become Nemeses, and an enemy that Drug Dealer removes while fleeing no longer counts
  as escaped.
  - **Turf:** in a zone V contests in Drug Dealer, its gangs ambush more (x1.25); in a zone V
    controls, they want it back (x1.5). The NEMESIS menu shows it: "TAKEN BY V" / "CONTESTED BY V"
    on each neighborhood, a line in the district detail, and "Territory lost to V: ..." on each gang.
  - **Terror:** Drug Dealer's terror makes gangers flee sooner (up to +15% on the flee health; the
    flee mark on the health bar moves with it).
- Both work only if the other mod is installed; without it nothing changes.

#### Changed
- **Tougher Nemeses.** They had the same health as a regular ganger. Now health scales with rank:
  Soldier x1.5, Lieutenant x2.5, Boss x4 (escorts unchanged). New Mod Settings category "Nemesis
  toughness" to tune each rank, plus an optional "Level based on V" (off by default: district level,
  as before) with extra levels per rank.
- **Quieter Nemesis notifications.** Updates (escapes, rumors, promotions, deaths...) now go to
  the side log, like looted items, with no sound and no screen buzz. The old big warning in the
  middle of the screen is still available: Mod Settings > General > "Center-screen notifications".
- **No notifications during cutscenes.** They wait until quest scenes (e.g. Johnny's memories),
  braindances and menus are over, then show one by one.

#### Fixed
- **Jackie removed from old saves.** 1.3.2 stopped Jackie from becoming a Nemesis, but a Jackie
  Nemesis created before that stayed in the save. It is now removed when the game loads.

### Español

#### Nuevo
- **Integración con They Will Remember (opcional).** Cuando un escuadrón de venganza de TWR de una
  banda con un Némesis vivo pelea con V, ese Némesis puede unirse y encabezarlo (misma probabilidad
  que los refuerzos en gigs). El rencor de TWR (banda hostil, muertes recientes) sube la probabilidad
  de emboscada, hasta x2.
  - **Aviso de venganza:** cuando TWR elige una banda para vengarse, su Jefe o Teniente Némesis que
    conoce a V le escribe antes (mensajes nuevos en el hilo "Número desconocido").
  - **El dinero no compra a un Némesis:** si V paga a una banda el perdón de TWR, TWR olvida, pero su
    Jefe o Teniente Némesis lo rechaza por mensaje. Sus emboscadas bajan a la mitad durante 3 días de
    juego.
- **Integración con Drug Dealer (opcional).** Las emboscadas, redadas y escaramuzas de Gang
  Retaliation esperan mientras un trabajo de Drug Dealer tenga enemigos vivos. Un Némesis puede
  aparecer con la banda que asalta tu negocio o defiende su territorio. Tu rango de dealer sube la
  probabilidad de emboscada (hasta x1.48). Tus soldados de Drug Dealer nunca se vuelven Némesis, y un
  enemigo que Drug Dealer borra mientras huye ya no cuenta como escapado.
  - **Territorio:** en una zona que V disputa en Drug Dealer, sus bandas emboscan más (x1.25); en una
    zona que V controla, la quieren recuperar (x1.5). El menú NÉMESIS lo muestra: "EN MANOS DE V" /
    "DISPUTADO CON V" en cada barrio, una línea en el detalle del distrito y "Territorio perdido ante
    V: ..." en cada banda.
  - **Terror:** el terror de Drug Dealer hace que los pandilleros huyan antes (hasta +15% en la vida
    para huir; la marca de huida en la barra de vida se mueve con él).
- Las dos funcionan solo si el otro mod está instalado; sin él no cambia nada.

#### Cambiado
- **Némesis más duros.** Tenían la misma vida que un pandillero normal. Ahora la vida depende del
  rango: Soldado x1.5, Teniente x2.5, Jefe x4 (la escolta no cambia). Nueva categoría en Mod Settings,
  "Dureza de los Némesis", para ajustar cada rango, y una opción "Nivel según V" (apagada por defecto:
  nivel del distrito, como antes) con niveles extra por rango.
- **Avisos de Némesis más discretos.** Las novedades (escapes, rumores, ascensos, muertes...) ahora
  van al registro lateral, como los objetos saqueados, sin sonido ni vibración de pantalla. El aviso
  grande en el centro sigue disponible: Mod Settings > General > "Avisos en el centro de la pantalla".
- **Sin avisos durante las escenas.** Esperan a que terminen las escenas de misión (p. ej. los
  recuerdos de Johnny), las danzas cerebrales y los menús, y después salen de a uno.

#### Arreglado
- **Jackie se borra de partidas viejas.** La 1.3.2 impidió que Jackie se volviera Némesis, pero un
  Jackie Némesis creado antes seguía en la partida. Ahora se borra al cargar el juego.

## [1.3.2] - 2026-11-02

### English

#### Fixed
- **Jackie (and other allies) could become a Nemesis.** Jackie is a Valentino, so hitting him by
  accident in a fight made him a candidate. Companions and NPCs friendly to V are now ignored.

#### Changed
- **Vehicle ambushes start on the street.** The car now spawns next to a car that is already in
  traffic or parked nearby, facing the same way as the lane and pointing towards V, with a walking
  path to V. Before, it used any walkable point, which could be a sidewalk or a plaza, so some
  ambushes ended up on foot. If there is no usable car nearby, it falls back to the old method.
  Idea taken from They Will Remember.
- **Ambush cars drive faster** (they used to arrive after V had already left).
- **NCPD raids no longer pop up in front of V.** They now spawn behind or to the sides, outside a
  70° cone in front of V and with no line of sight. Every cop and ganger is checked, not just the
  center of each group (some used to appear in sight, inside walls or on another floor).
- **NCPD and gangers just staring at each other in raids.** Hostility between the two sides was
  set only once, when each NPC spawned; if its AI was not ready yet, it stayed passive. Now, every
  3 seconds, anyone not fighting is pointed at the nearest living enemy (like the passive Nemesis
  fix for ambushes).

### Español

#### Arreglado
- **Jackie (y otros aliados) podían volverse Némesis.** Jackie es Valentino, así que pegarle sin
  querer en una pelea lo volvía candidato. Ahora se ignoran los acompañantes y los NPC amistosos
  con V.

#### Cambiado
- **Las emboscadas en vehículo arrancan en la calle.** El auto ahora aparece junto a un auto que ya
  está en el tráfico o estacionado cerca, mirando como el carril y hacia V, con camino a pie hasta V.
  Antes usaba cualquier punto caminable, que podía ser una vereda o una plaza, y algunas emboscadas
  terminaban a pie. Si no hay un auto útil cerca, usa el método anterior. Idea tomada de They Will
  Remember.
- **Los autos de emboscada manejan más rápido** (antes llegaban cuando V ya se había ido).
- **Las redadas de la NCPD ya no aparecen delante de V.** Ahora aparecen detrás o a los costados,
  fuera de un cono de 70° delante de V y sin línea de vista. Se revisa a cada policía y pandillero,
  no solo el centro de cada grupo (algunos aparecían a la vista, dentro de paredes o en otro piso).
- **Policías y pandilleros que se quedaban mirándose en las redadas.** La hostilidad entre los dos
  bandos se ponía una sola vez, al aparecer cada NPC; si su IA no estaba lista, quedaba pasivo.
  Ahora, cada 3 segundos, a quien no esté peleando se le marca el enemigo vivo más cercano (como el
  arreglo de Némesis pasivos en las emboscadas).

## [1.3.1] - 2026-11-01

### English

#### Fixed
- **"I'm back" SMS missing from the phone.** When a Nemesis returned from the ripperdoc, the
  message only showed as a popup and never reached the inbox. It now goes to the "Unknown number"
  thread like the ambush threats.
- **Crashes in big fights and when combat ends.** The game delivers hits, deaths and combat changes
  on several threads at once. The mod updated its fight lists right there, so two threads could change them together and crash the game (reported with Wraiths in the Badlands). Now those events only queue a call, and the mod handles them on the main
  thread. Fighters are also kept by ID instead of by reference.

### Español

#### Arreglado
- **SMS de "volví" que no estaba en el teléfono.** Cuando un Némesis volvía del matasanos, el
  mensaje solo salía como aviso y nunca llegaba a la bandeja. Ahora va al hilo "Número
  desconocido", como las amenazas de emboscada.
- **Crashes en peleas grandes y al terminar el combate.** El juego entrega los golpes, las muertes y
  los cambios de combate en varios hilos a la vez (un escopetazo a un grupo, por ejemplo). El mod
  actualizaba sus listas de la pelea ahí mismo, así que dos hilos podían tocarlas juntos y el juego
  crasheaba (reportado con Wraiths en las Badlands). Ahora esos eventos solo agendan una llamada y
  el mod los procesa en el hilo principal. Los peleadores además se guardan por ID y no por
  referencia.

## [1.3.0] - 2026-10-31

### English

#### New
- **Bigger enemy health bar.** The bar over the enemy you look at can be scaled up (x1.5 by default,
  x1 to x2 in Mod Settings).
- **Flee line.** A yellow line on the enemy's health bar marks the health at which they'll run away
  if left last standing. It only shows when that ganger really can flee: not in scenes, vehicles or
  on bosses, so it never promises an escape that won't happen.
- **THREATS panel.** In combat, a box on the left lists the enemies targeting you. Each row shows
  the gang color, the name (the Nemesis name if it is one, otherwise the gang), the distance and a
  small health bar with its own flee line. Below the threshold, the bar turns amber.
  - The enemy you're looking at comes first, then Nemeses, then by distance. The rest show as
    "+N more".
  - It hides 3 s after combat and while the weapon wheel is open.
  - Same size at any resolution.
- **HUD options in Mod Settings** (new HUD category): enemy bar size, flee line on/off, threats
  panel on/off, panel X/Y position, size, background opacity and number of rows. Everything applies
  live, no restart needed.

#### Changed
- **Tracking a job no longer disables fleeing.** Before, with a main or side job tracked, nobody
  fled anywhere on the map, and almost everyone always tracks a job. Now fleeing is only blocked
  when V is within 150 m of that job's objective.
- **Gangers who flee and survive become Nemeses.** A ganger who fled and turned back to fight (so
  they don't leave the area) now becomes a Nemesis if still alive when combat ends, even with more
  health than the "wounded escape" threshold.
- **SMS-announced ambushes wait longer.** If they can't start (V in combat, indoors, in a vehicle),
  they retry for 30 minutes instead of 10 before being cancelled.

#### Fixed
- **Ambushes blocked by They Will Remember corpses.** The TWR squad check also counted dead members,
  which TWR doesn't remove while you're nearby. Now only living ones count.
- **Boss health bar stuck on screen.** When the Nemesis died, the ambush ended or you moved away
  (even by fast travel), the boss bar could stay at the top of the screen. It's now checked every
  second and removed if the Nemesis no longer exists, is dead or downed, or is more than 100 m away.
- **Nemeses spawning passive.** If the NPC wasn't ready when it spawned, it never entered combat
  and just stood there. Now, during the ambush, those still out of combat near V are provoked again
  every 3 s (up to 6 times).

### Español

#### Nuevo
- **Barra de vida del enemigo más grande.** La barra sobre el enemigo que mirás se puede agrandar
  (x1.5 por defecto, de x1 a x2 en Mod Settings).
- **Línea de huida.** Una línea amarilla en la barra del enemigo marca con cuánta vida va a huir si
  queda último en pie. Solo aparece cuando ese pandillero de verdad puede huir: no en escenas, en
  vehículos ni con jefes, así que nunca promete una huida que no va a pasar.
- **Panel AMENAZAS.** En combate, un recuadro a la izquierda lista a los enemigos que te tienen como
  objetivo. Cada fila lleva el color de la banda, el nombre (el del Némesis si lo es, si no el de la
  banda), la distancia y una barra de vida pequeña con su propia línea de huida. Por debajo del
  umbral, la barra se pone ámbar.
  - Primero el enemigo que mirás, después los Némesis y después por distancia. Los que no entran
    aparecen como "+N más".
  - Se oculta 3 s después del combate y mientras está abierta la rueda de armas.
  - Se ve del mismo tamaño en cualquier resolución.
- **Opciones de HUD en Mod Settings** (nueva categoría HUD): tamaño de la barra enemiga, línea de
  huida sí/no, panel de amenazas sí/no, posición X/Y del panel, tamaño, opacidad del fondo y
  cantidad de filas. Todo se aplica en vivo, sin reiniciar.

#### Cambiado
- **Seguir una misión ya no apaga las huidas.** Antes, con una misión principal o secundaria
  seguida, nadie huía en ningún lugar del mapa, y casi todos siguen siempre alguna misión. Ahora
  solo se bloquea la huida si V está a menos de 150 m del objetivo de esa misión.
- **Los que huyen y sobreviven se vuelven Némesis.** Un pandillero que huyó y vuelve a pelear para
  no salir de la zona ahora se convierte en Némesis si sigue vivo al terminar el combate, aunque
  tenga más vida que el umbral de "huida herida".
- **La emboscada anunciada por SMS espera más.** Si no puede salir (V en combate, bajo techo, en
  vehículo), reintenta durante 30 minutos en vez de 10 antes de cancelarse.

#### Arreglado
- **Emboscadas bloqueadas por cadáveres de They Will Remember.** El bloqueo por escuadrón de TWR
  contaba también a los miembros muertos, que TWR no borra mientras estés cerca. Ahora solo cuentan
  los vivos.
- **Barra de jefe trabada en pantalla.** Cuando el Némesis moría, la emboscada terminaba o te
  alejabas (incluso teletransportándote), la barra de jefe podía quedarse arriba de la pantalla.
  Ahora se revisa cada segundo y se quita si el Némesis ya no existe, está muerto o derribado, o
  quedó a más de 100 m.
- **Némesis que aparecían pasivos.** Si el NPC todavía no estaba listo cuando aparecía, no entraba
  en combate y se quedaba quieto. Ahora, mientras dura la emboscada, los que siguen fuera de combate
  cerca de V se vuelven a provocar cada 3 s (hasta 6 veces).

## [1.2.2] - 2026-10-29

### Arreglado
- **Crash al terminar un combate** (`GRDetection.OnPlayerCombatEnded`, reportado con They Will
  Remember, Dark Future y EDO). El texto de depuración se armaba siempre, aunque el log de
  depuración estuviera apagado, y la lista de candidatos se recorría mientras otro evento podía
  modificarla.
- **Némesis falsos con mods que borran NPCs.** Un pandillero que desaparece al acabar el combate
  (por ejemplo, un escuadrón de They Will Remember que el mod borra) ya no se asciende como
  "escapó herido".
- **"No se pudo escribir data/gang_retaliation.json".** Vortex no instalaba la carpeta `data`
  vacía y el mod no podía guardar a sus Némesis. Ahora viene con un archivo `.keep` adentro.

### Cambiado
- **Rendimiento.** La capa CET ya no consulta al juego en cada frame: todo va en un tick de 1 s.
  El menú NÉMESIS se reconstruye solo cuando cambian los datos, y no cada 2 s aunque esté
  cerrado. Medido con 44 Némesis: los picos bajan de 11 ms a 4 ms y casi no hay gasto en reposo.
- **Compatibilidad con They Will Remember.** Mientras haya un escuadrón de venganza de TWR en el
  mapa, no salen emboscadas, redadas de la NCPD ni escaramuzas de Gang Retaliation, para no
  sumar dos ataques a la vez. Sin TWR instalado no cambia nada.

## [1.2.1] - 2026-10-29

### Nuevo
- **Emboscadas en vehículo.** El Némesis y su escolta pueden llegar en coche, aparcar y bajarse.
  Si no hay sitio detrás de V, llegan a pie.
- **Casas de V.** Cerca de una casa de V no hay emboscadas (probabilidad 0 a menos de 60 m,
  normal a más de 300 m). El departamento H10 viene de fábrica; el resto se aprende al dormir
  2 noches en él.

### Arreglado
- **Emboscadas dentro del departamento o en pasillos.** Ahora solo aparecen a cielo abierto: si V
  está bajo techo, la emboscada anunciada espera a que salga. Tampoco salen en escenas donde V no
  puede sacar el arma.
- **Misiones que no se podían terminar porque el último enemigo huía.** No hay huidas en las
  misiones de historia que V tiene seguidas, y los NPCs del mundo ya no salen de la zona al huir.
- **Emboscadas atascadas.** Se cierran solas a los 40 s.
- Durante una emboscada, defenderse no cuenta como delito.

## [1.2] - 2026-10-28

### Nuevo
- **Redadas de la NCPD cerca de V.** Un Némesis de la zona y su escolta se enfrentan a una patrulla
  de 3 a 5 policías (más cuanto más alto el rango), a unos 30 m de V.
  - Probabilidad por minuto configurable en Mod Settings ("Redadas de la NCPD cerca de V", 10%),
    como mucho una cada 15 minutos.
  - V puede mirar, ayudar a la policía o ayudar a la banda. La banda nace hostil con V (así
    dispararle no es delito) y la policía, amistosa.
  - Durante la redada nadie huye: el Némesis pelea hasta el final.
  - Si el Némesis sobrevive, gana 2 de renombre y corre el rumor de que escapó.
- **Recompensa de la NCPD.** Si la banda cae entera con ayuda de V, la NCPD paga según el rango
  del Némesis: 1.000 / 2.500 / 5.000 eurodólares. Si V le pegó a algún policía, se descuenta la
  mitad "por gastos médicos de los agentes".
- **Contacto "NCPD" en el teléfono**, con su hilo "NCPD - Recompensas": 6 mensajes de pago
  normal y 3 de pago con descuento, en ES (con variantes para V mujer y V hombre) y EN.
- **Inmunidad ante la policía durante las redadas.** Desde que empieza hasta que termina y V
  enfunda el arma (como mucho 60 s después): nada de lo que haga V cuenta como delito, sin
  estrellas de búsqueda aunque una bala perdida le dé a un policía. Los policías de la redada se
  mantienen amistosos con V.
- **Tiroteos simulados con la NCPD** (fuera de cámara). Cada día, cada banda tiene una
  probabilidad (Mod Settings, "Tiroteos con la NCPD", 10%) de que la policía choque con uno de
  sus Némesis. Resultado: escapa (+2 renombre), muere (puede volver, como cualquier muerte
  normal) o lo arrestan 2-5 días. Mientras está arrestado no embosca ni sale en encargos. Todo
  llega como rumores.
- **Causa de muerte de cada Némesis.** Se registra quién le dio el último golpe: V (incluidos
  sus aliados, torretas y drones), la NCPD, otra banda u otra causa (caída, accidente). Se ve en
  el aviso y en el menú NÉMESIS (sección Caídos: "A manos de la NCPD", "A manos de Maelstrom"…).
- **Barra de vida de jefe** del juego para los Némesis vivos (no para su escolta), con su nombre
  completo. Se desactiva con el ajuste `bossBar`.

### Cambiado
- Solo las muertes a manos de V debilitan a la banda en la guerra de bandas. Un remate (disparo
  a la cabeza, explosión, desmembramiento) solo deja muerto para siempre al Némesis si lo dio V.
  Arreglo de compatibilidad con mods que añaden tiroteos entre bandas y policía (NCA).
- **Versión dev y versión release.** La carpeta de trabajo mantiene la ventana de CET
  "Gang Retaliation (dev)" con todos los botones de debug. El zip de `release.py` sale con una
  ventana mínima (campaña, Némesis vivos y muertos, día de juego).
- Nuevos botones de debug: "Debug: force NCPD clash" y "Debug: NCPD raid now".

### Corregido
- **Crash intermitente al huir el último en pie.** La huida se ejecutaba dentro del golpe de V o
  de la muerte de un compañero, a veces sobre un NPC que se estaba muriendo. Ahora se anota y se
  ejecuta en el siguiente tick, después de volver a comprobar que el NPC siga vivo. Además, si V
  y el NPC están pegados, la dirección de huida ya no sale inválida.
- La policía disparaba a V aunque la ayudara en una redada: la banda nacía neutral, así que
  atacarla contaba como delito.
- No se cobraba la recompensa si el Némesis huía a un sitio inalcanzable en mitad de la redada.
- Los mensajes de la policía hablan de "eurodólares" (oficial), no de "eddies" (jerga callejera).
- Se quitó el aviso en pantalla de la recompensa, que repetía lo que ya decía el SMS. Solo sale
  si el SMS no se puede mandar.

### Aviso
- La v1.0.0 publicada en Nexus incluía la ventana de debug completa de CET. Esta versión la
  quita del zip de release.
