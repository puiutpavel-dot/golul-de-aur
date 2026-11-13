// Golul de Aur - sincronizare (ruleaza din GitHub Actions la fiecare 30 de minute).
// 1) O data pe zi, la prima rulare de dupa miezul noptii (ora Romaniei), alege meciul zilei:
//    cel cu cele mai apropiate cote 1-X-2. GitHub intarzie des rularile programate (uneori cu ore),
//    asa ca alegem cat mai devreme, ca meciul sa fie in aplicatie dimineata.
// 2) Dupa meci, ia scorul final.
// Rezultatul se scrie in data/matches.json, de unde il citeste aplicatia.
import { readFile, writeFile } from "node:fs/promises";

const DATA_FILE = new URL("../data/matches.json", import.meta.url);
const ODDS_BASE = "https://api.the-odds-api.com/v4";
const PICK_HOUR = 0; // ora Romaniei de la care se alege meciul zilei
const MAX_LEAGUES = 8; // cate competitii verificam pe zi (1 credit fiecare)
const MIN_BOOKMAKERS = 3;
const KEEP_MATCHES = 45;

// Ordinea de preferinta a competitiilor. Sunt folosite doar cele active.
const PREFERRED = [
  "soccer_fifa_world_cup",
  "soccer_uefa_european_championship",
  "soccer_uefa_champs_league",
  "soccer_uefa_nations_league",
  "soccer_uefa_europa_league",
  "soccer_epl",
  "soccer_spain_la_liga",
  "soccer_italy_serie_a",
  "soccer_germany_bundesliga",
  "soccer_france_ligue_one",
  "soccer_fifa_world_cup_qualifiers_europe",
  "soccer_uefa_europa_conference_league",
  "soccer_netherlands_eredivisie",
  "soccer_portugal_primeira_liga",
];

function bucharestNow() {
  const parts = new Intl.DateTimeFormat("en-CA", {
    timeZone: "Europe/Bucharest",
    year: "numeric", month: "2-digit", day: "2-digit", hour: "2-digit", hourCycle: "h23",
  }).formatToParts(new Date());
  const get = (type) => parts.find((p) => p.type === type)?.value ?? "";
  return { day: `${get("year")}-${get("month")}-${get("day")}`, hour: Number(get("hour")) };
}

const isoNoMillis = (date) => date.toISOString().replace(/\.\d{3}Z$/, "Z");
const round2 = (value) => Math.round(value * 100) / 100;

export function toCandidate(event) {
  let home = 0, draw = 0, away = 0, count = 0;
  for (const bookmaker of event.bookmakers ?? []) {
    const market = (bookmaker.markets ?? []).find((m) => m.key === "h2h");
    if (!market) continue;
    const price = (name) => market.outcomes?.find((o) => o.name === name)?.price;
    const h = price(event.home_team), d = price("Draw"), a = price(event.away_team);
    if (typeof h !== "number" || typeof d !== "number" || typeof a !== "number") continue;
    home += h; draw += d; away += a; count += 1;
  }
  if (count < MIN_BOOKMAKERS) return null;
  const odds = [home / count, draw / count, away / count];
  return {
    match: {
      event_id: event.id,
      sport_key: event.sport_key,
      league: event.sport_title ?? event.sport_key,
      home_team: event.home_team,
      away_team: event.away_team,
      commence_time: event.commence_time,
      odds_home: round2(odds[0]),
      odds_draw: round2(odds[1]),
      odds_away: round2(odds[2]),
      status: "scheduled",
      home_score: null,
      away_score: null,
      result: null,
      last_settle_attempt: null,
    },
    // Cu cat diferenta dintre cea mai mare si cea mai mica cota e mai mica,
    // cu atat meciul e mai echilibrat.
    spread: Math.max(...odds) - Math.min(...odds),
  };
}

async function pickMatch(apiKey, day, hour) {
  const sportsRes = await fetch(`${ODDS_BASE}/sports/?apiKey=${apiKey}`); // nu consuma credite
  if (!sportsRes.ok) throw new Error(`sports ${sportsRes.status}`);
  const active = new Set((await sportsRes.json()).filter((s) => s.active).map((s) => s.key));
  const leagues = PREFERRED.filter((key) => active.has(key)).slice(0, MAX_LEAGUES);

  const from = isoNoMillis(new Date(Date.now() + 60 * 60 * 1000));
  // Pana la sfarsitul zilei din Romania, ca meciul ales sa se joace chiar azi.
  const to = isoNoMillis(new Date(Date.now() + Math.max(2, 24 - hour) * 60 * 60 * 1000));
  const candidates = [];

  for (const league of leagues) {
    const url = `${ODDS_BASE}/sports/${league}/odds/?apiKey=${apiKey}&regions=eu&markets=h2h` +
      `&oddsFormat=decimal&dateFormat=iso&commenceTimeFrom=${from}&commenceTimeTo=${to}`;
    const res = await fetch(url);
    if (!res.ok) { console.log(`cote ${league}: ${res.status}`); continue; }
    for (const event of await res.json()) {
      const candidate = toCandidate(event);
      if (candidate) candidates.push(candidate);
    }
  }
  if (candidates.length === 0) return null;
  candidates.sort((a, b) => a.spread - b.spread);
  return { day, ...candidates[0].match };
}

async function settle(apiKey, match) {
  const now = Date.now();
  const kickoff = new Date(match.commence_time).getTime();
  if (now < kickoff + SETTLE_AFTER_MS) return; // asteptam start + 2h15
  if (match.last_settle_attempt && now - new Date(match.last_settle_attempt).getTime() < SETTLE_EVERY_MS) return;
  match.last_settle_attempt = isoNoMillis(new Date());

  if (now - kickoff > 60 * 3_600_000) {
    // Scorul nu a mai aparut (meci amanat/anulat): nimeni nu urca, nimeni nu coboara.
    match.status = "void";
    console.log(`anulat: ${match.home_team} - ${match.away_team}`);
    return;
  }

  const url = `${ODDS_BASE}/sports/${match.sport_key}/scores/?apiKey=${apiKey}` +
    `&daysFrom=3&eventIds=${match.event_id}`;
  const res = await fetch(url);
  if (!res.ok) { console.log(`scor: ${res.status}`); return; }
  const event = (await res.json()).find((e) => e.id === match.event_id);
  if (!event?.completed || !event.scores) return;

  const scoreOf = (team) => Number(event.scores.find((s) => s.name === team)?.score);
  const homeScore = scoreOf(match.home_team), awayScore = scoreOf(match.away_team);
  if (Number.isNaN(homeScore) || Number.isNaN(awayScore)) return;

  match.status = "finished";
  match.home_score = homeScore;
  match.away_score = awayScore;
  match.result = homeScore > awayScore ? "1" : homeScore < awayScore ? "2" : "X";
  console.log(`final: ${match.home_team} ${homeScore}-${awayScore} ${match.away_team}`);
}

const SETTLE_AFTER_MS = 135 * 60 * 1000; // primul scor il cautam la start + 2h15
const SETTLE_EVERY_MS = 25 * 60 * 1000; // apoi cel mult o data la 25 de minute
const WAIT_WINDOW_MS = 5 * 3_600_000; // cat timp dupa start mai asteptam scorul in aceeasi rulare

// Cate secunde sa mai astepte rularea curenta pana la urmatoarea cautare a scorului.
// 0 = niciun meci in desfasurare sau in asteptarea scorului. GitHub intarzie rularile programate
// cu ore, asa ca rularea care prinde meciul inceput ramane pornita pana apare scorul final.
export function secondsUntilNextSettle(data, now = Date.now()) {
  let wait = 0;
  for (const match of data.matches) {
    if (match.status !== "scheduled") continue;
    const kickoff = new Date(match.commence_time).getTime();
    if (now < kickoff || now > kickoff + WAIT_WINDOW_MS) continue;
    let next = kickoff + SETTLE_AFTER_MS;
    if (match.last_settle_attempt) {
      next = Math.max(next, new Date(match.last_settle_attempt).getTime() + SETTLE_EVERY_MS);
    }
    const seconds = Math.max(60, Math.ceil((next - now) / 1000) + 30);
    wait = wait === 0 ? seconds : Math.min(wait, seconds);
  }
  return wait;
}

export async function main() {
  const apiKey = process.env.ODDS_API_KEY;
  if (!apiKey) throw new Error("Lipseste secretul ODDS_API_KEY");

  const before = await readFile(DATA_FILE, "utf8");
  const data = JSON.parse(before);
  const { day, hour } = bucharestNow();

  if (hour >= PICK_HOUR && data.last_pick_day !== day) {
    // Marcam ziua chiar daca apelul esueaza, ca sa nu consumam credite de doua ori.
    data.last_pick_day = day;
    try {
      const match = await pickMatch(apiKey, day, hour);
      if (match) {
        data.matches = [match, ...data.matches.filter((m) => m.day !== day)].slice(0, KEEP_MATCHES);
        console.log(`ales: ${match.home_team} - ${match.away_team}`);
      } else {
        console.log("niciun meci gasit azi");
      }
    } catch (error) {
      console.log(`alegerea meciului a esuat: ${error.message}`);
    }
  }

  for (const match of data.matches) {
    if (match.status === "scheduled") await settle(apiKey, match);
  }

  const after = JSON.stringify(data, null, 2) + "\n";
  if (after !== before) await writeFile(DATA_FILE, after);
}

if (import.meta.url === `file://${process.argv[1]}`) {
  if (process.argv.includes("--wait")) {
    console.log(secondsUntilNextSettle(JSON.parse(await readFile(DATA_FILE, "utf8"))));
  } else {
    await main();
  }
}
