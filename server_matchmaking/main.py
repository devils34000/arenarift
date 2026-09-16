from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Any, Optional
from uuid import uuid4
from datetime import datetime, timezone
import os
import random
import socket
import string
import subprocess
import threading


app = FastAPI(title="ARENA RIFT Matchmaking")


# =========================================================
# CONFIGURATION
# =========================================================

GAME_SERVER_IP = "149.202.91.92"

# URL publique de CE service, transmise au serveur de jeu qu'on lance, pour
# qu'il puisse nous rappeler ("je suis prêt" / "la partie est finie").
MATCHMAKING_PUBLIC_URL = "http://149.202.91.92:8080"

GAME_SERVER_START_PORT = 2456
GAME_SERVER_MAX_PORT = 2500

GAME_SERVER_DIR = "/opt/arena-rift-server"
GAME_SERVER_EXECUTABLE = os.path.join(
    GAME_SERVER_DIR,
    "arena_rift_server.x86_64"
)

# Un ticket de recherche jamais apparié au-delà de ce délai est considéré
# abandonné (appli fermée, recherche annulée sans le dire, etc.) et expire.
TICKET_TTL_SECONDS = 120

# Un match terminé (ou en erreur) est gardé ce temps-là en mémoire pour le
# debug/consultation, puis purgé pour ne pas accumuler indéfiniment.
MATCH_RETENTION_SECONDS = 600

# Un salon Custom Game (code Among-Us-like) jamais lancé au-delà de ce délai
# d'inactivité est purgé, pour ne pas accumuler des codes morts.
ROOM_TTL_SECONDS = 1800

# Caractères utilisés pour générer les codes de salon : on évite les
# caractères ambigus à l'oral/à l'écrit (0/O, 1/I/L) pour que ce soit
# facile à se dicter entre amis, façon code de salon Among Us.
ROOM_CODE_ALPHABET = "ABCDEFGHJKMNPQRSTUVWXYZ23456789"
ROOM_CODE_LENGTH = 5


# =========================================================
# DATA
# =========================================================

# Toute lecture/écriture des dictionnaires ci-dessous doit se faire sous ce
# verrou : FastAPI exécute les routes "def" classiques dans un pool de
# threads, donc deux requêtes peuvent arriver en vrai parallèle.
_lock = threading.Lock()

# Un ticket = une party (Steam) en recherche de match. Clé = ticket_id
# (généré à chaque recherche, jetable — jamais réutilisé d'une recherche à
# l'autre, contrairement à l'ancien système basé sur le lobby_id).
tickets: dict[str, dict[str, Any]] = {}

# Un match = une partie effectivement lancée sur un serveur de jeu dédié
# (matchmaking classique ET Custom Game partagent cette même table).
matches: dict[str, dict[str, Any]] = {}

# Un salon Custom Game = un code que les joueurs se partagent entre eux
# (vocal, Discord...) pour rejoindre la même partie, façon Among Us —
# aucun lien avec un lobby Steam, aucune liste d'amis nécessaire.
rooms: dict[str, dict[str, Any]] = {}

# Process du serveur de jeu dédié, par port utilisé.
game_servers: dict[int, subprocess.Popen] = {}


# =========================================================
# MODELS
# =========================================================

class MatchRequest(BaseModel):
    game: str
    lobby_id: str
    leader_steam_id: str
    mode: str
    max_members: int
    members: list[dict[str, Any]]


class MatchReport(BaseModel):
    # "ready"    : le serveur dédié a fini de charger et accepte les
    #              connexions (envoyé une fois, juste après Network.host()).
    # "finished" : la partie est terminée et tout le monde est parti, le
    #              serveur dédié va s'éteindre (envoyé juste avant de quitter).
    event: str


class CreateRoomRequest(BaseModel):
    steam_id: str
    name: str


class JoinRoomRequest(BaseModel):
    steam_id: str
    name: str


class RoomTeamRequest(BaseModel):
    steam_id: str
    team: str  # "ASTRAL" | "ARCANE" | ""


class RoomSettingsRequest(BaseModel):
    steam_id: str
    map: Optional[str] = None
    mode: Optional[str] = None  # "TEAM" | "FFA" | "EXPLORE"
    random_teams: Optional[bool] = None


class RoomLeaveRequest(BaseModel):
    steam_id: str


class RoomStartRequest(BaseModel):
    steam_id: str


def _now() -> datetime:
    return datetime.now(timezone.utc)


# =========================================================
# SERVER PROCESS MANAGEMENT
# =========================================================

def is_port_available(port: int) -> bool:
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

    try:
        sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        sock.bind(("0.0.0.0", port))
        return True

    except OSError:
        return False

    finally:
        sock.close()


def find_free_game_server_port() -> Optional[int]:
    for port in range(
        GAME_SERVER_START_PORT,
        GAME_SERVER_MAX_PORT + 1
    ):
        if port in game_servers:
            process = game_servers[port]

            if process.poll() is None:
                continue

            del game_servers[port]

        if is_port_available(port):
            return port

    return None


def start_game_server(match_id: str, game_mode: str) -> dict[str, Any]:
    print("")
    print("========================================")
    print("ARENA RIFT : DEMANDE SERVEUR DE JEU")
    print("MATCH :", match_id)
    print("========================================")

    if not os.path.isfile(GAME_SERVER_EXECUTABLE):
        print("ERREUR : executable serveur introuvable")
        print("CHEMIN :", GAME_SERVER_EXECUTABLE)
        return {
            "status": "error",
            "error": "Dedicated server executable introuvable"
        }

    port = find_free_game_server_port()

    if port is None:
        print("ERREUR : aucun port serveur disponible")
        return {
            "status": "error",
            "error": "Aucun port serveur disponible"
        }

    command = [
        GAME_SERVER_EXECUTABLE,
        "--headless",
        "--server",
        # IMPORTANT : tout ce qui suit "--" est ce que Godot expose via
        # OS.get_cmdline_user_args().
        "--",
        "--port",
        str(port),
        "--match",
        match_id,
        "--mode",
        game_mode,
        "--matchmaking-url",
        MATCHMAKING_PUBLIC_URL,
    ]

    print("SERVEUR :", GAME_SERVER_EXECUTABLE)
    print("PORT    :", port)
    print("COMMAND :", " ".join(command))

    try:
        log_file_path = os.path.join(
            GAME_SERVER_DIR,
            f"{match_id}.log"
        )

        log_file = open(
            log_file_path,
            "a",
            buffering=1
        )

        process = subprocess.Popen(
            command,
            cwd=GAME_SERVER_DIR,
            stdout=log_file,
            stderr=log_file
        )

    except Exception as error:
        print("ERREUR LANCEMENT SERVEUR :", error)
        return {
            "status": "error",
            "error": str(error)
        }

    game_servers[port] = process

    print("SERVEUR LANCE")
    print("PID :", process.pid)
    print("PORT :", port)

    return {
        "status": "starting",
        "ip": GAME_SERVER_IP,
        "port": port,
        "pid": process.pid
    }


def refresh_server_status_locked(server: Optional[dict[str, Any]]) -> Optional[dict[str, Any]]:
    """Appelé sous _lock. Le serveur dédié rapporte lui-même "ready"/"finished"
    via /matches/{id}/report — c'est la source de vérité principale. Le poll
    du process ici n'est qu'un filet de sécurité (crash, oubli de rapport)."""

    if server is None:
        return None

    if server.get("status") in ("stopped", "error"):
        return server

    port = server.get("port")

    if port is None:
        return server

    process = game_servers.get(int(port))

    if process is not None and process.poll() is not None:
        server["status"] = "stopped"

    return server


# =========================================================
# TICKETS DE MATCHMAKING (mode automatique : DM/1v1/2v2/3v3)
# =========================================================

def prune_locked() -> None:
    """Appelé sous _lock. Fait expirer les vieux tickets, purge les matches
    terminés depuis trop longtemps et les salons Custom Game inactifs."""

    now = _now()

    for ticket in tickets.values():
        if ticket["status"] == "searching":
            age = (now - ticket["created_at"]).total_seconds()
            if age > TICKET_TTL_SECONDS:
                ticket["status"] = "expired"

        elif ticket["status"] == "matched":
            # Sans ceci, un ticket restait "matched" pour toujours, même une
            # fois la partie terminée : une nouvelle recherche sur le même
            # lobby retombait sur ce ticket mort (match "finished", serveur
            # "stopped") au lieu de démarrer une recherche fraîche — le
            # client bouclait alors indéfiniment sur "SERVEUR EN
            # DÉMARRAGE..." sans jamais rien trouver de nouveau.
            linked_match = matches.get(ticket.get("match_id"))
            if linked_match is not None and linked_match["status"] in ("finished", "error"):
                ticket["status"] = "completed"

    for match_id in list(matches.keys()):
        match = matches[match_id]
        if match["status"] in ("finished", "error"):
            finished_at = match.get("finished_at") or match["created_at"]
            age = (now - finished_at).total_seconds()
            if age > MATCH_RETENTION_SECONDS:
                del matches[match_id]

    for code in list(rooms.keys()):
        room = rooms[code]
        age = (now - room["last_activity_at"]).total_seconds()
        if room["status"] == "closed" or age > ROOM_TTL_SECONDS:
            del rooms[code]


def searching_tickets_locked() -> list[dict[str, Any]]:
    return [t for t in tickets.values() if t["status"] == "searching"]


def find_compatible_ticket_locked(ticket: dict[str, Any]) -> Optional[dict[str, Any]]:
    for other in searching_tickets_locked():

        if other["ticket_id"] == ticket["ticket_id"]:
            continue

        if other["lobby_id"] == ticket["lobby_id"]:
            continue

        if other["mode"] != ticket["mode"]:
            continue

        return other

    return None


def game_mode_to_server_mode(mode: str) -> str:
    """dedicated_server.gd reconnaît trois mots-clés de carte : "1v1"
    (Arena1v1.tscn), "labyrinth" (ArenaLabyrinth.tscn) et "default"
    (arena.tscn / Demo.tscn). On les fait correspondre ici au nom de mode
    affiché au joueur pour le matchmaking automatique (le Custom Game
    envoie sa propre map directement, cf. rooms)."""

    if mode.strip().upper() == "1V1 DUEL":
        return "1v1"

    return "default"


def create_match_locked(ticket_a: dict[str, Any], ticket_b: dict[str, Any]) -> dict[str, Any]:
    match_id = "AR-" + uuid4().hex[:8].upper()

    match: dict[str, Any] = {
        "match_id": match_id,
        "game": "ARENA_RIFT",
        "mode": ticket_a["mode"],
        "status": "starting_server",
        "created_at": _now(),
        "finished_at": None,

        "tickets": [ticket_a["ticket_id"], ticket_b["ticket_id"]],
        "parties": [
            {
                "lobby_id": ticket_a["lobby_id"],
                "leader_steam_id": ticket_a["leader_steam_id"],
                "members": ticket_a["members"],
            },
            {
                "lobby_id": ticket_b["lobby_id"],
                "leader_steam_id": ticket_b["leader_steam_id"],
                "members": ticket_b["members"],
            },
        ],

        "server": None,
    }

    matches[match_id] = match

    server_result = start_game_server(match_id, game_mode_to_server_mode(ticket_a["mode"]))

    if server_result["status"] == "error":
        match["status"] = "error"
        match["finished_at"] = _now()
        match["server"] = {
            "status": "error",
            "error": server_result["error"],
        }
        return match

    match["status"] = "matched"
    match["server"] = {
        "status": "starting",
        "ip": server_result["ip"],
        "port": server_result["port"],
        "pid": server_result["pid"],
    }

    print("")
    print("########################################")
    print("MATCH PRET")
    print("########################################")
    print("MATCH ID :", match_id)
    print("IP       :", server_result["ip"])
    print("PORT     :", server_result["port"])
    print("########################################")
    print("")

    return match


def serialize_ticket_locked(ticket: dict[str, Any]) -> dict[str, Any]:
    result: dict[str, Any] = {
        "ticket_id": ticket["ticket_id"],
        "status": ticket["status"],
        "mode": ticket["mode"],
    }

    if ticket["status"] == "searching":
        pool = searching_tickets_locked()
        if ticket in pool:
            result["position"] = pool.index(ticket) + 1

    if ticket.get("match_id"):
        match = matches.get(ticket["match_id"])
        if match is not None:
            server = refresh_server_status_locked(match.get("server"))
            result["match_id"] = match["match_id"]
            result["match_status"] = match["status"]
            result["server"] = server

    return result


# =========================================================
# ROOT
# =========================================================

@app.get("/")
def root():

    return {
        "game": "ARENA_RIFT",
        "service": "matchmaking",
        "status": "online"
    }


@app.get("/health")
def health():

    return {
        "status": "ok"
    }


# =========================================================
# MATCHMAKE (créer / récupérer un ticket de recherche)
# =========================================================

@app.post("/matchmake")
def matchmake(request: MatchRequest):

    party = request.model_dump()

    print("")
    print("========================================")
    print("NOUVELLE PARTY")
    print("Lobby :", party["lobby_id"])
    print("Leader:", party["leader_steam_id"])
    print("Mode  :", party["mode"])
    print("Joueurs:", len(party["members"]))
    print("========================================")

    if party["game"] != "ARENA_RIFT":
        raise HTTPException(status_code=400, detail="Jeu invalide")

    with _lock:
        prune_locked()

        for ticket in tickets.values():
            if ticket["lobby_id"] != party["lobby_id"]:
                continue

            if ticket["status"] == "searching":
                # Recherche déjà en cours pour ce lobby : on la renvoie telle
                # quelle plutôt que d'en créer une doublon (double-clic, etc).
                print("TICKET DEJA EN RECHERCHE POUR CE LOBBY :", ticket["ticket_id"])
                return serialize_ticket_locked(ticket)

            if ticket["status"] == "matched":
                # Le joueur relance une recherche depuis le menu : il a donc
                # forcément quitté son match précédent (le client ne peut pas
                # revenir sur cet écran sans ça). Ça ne dépend PAS de l'état
                # du vieux serveur de jeu, qui continue de s'éteindre de son
                # côté indépendamment : on abandonne l'ancien ticket tout de
                # suite et on laisse une recherche fraîche démarrer, sans
                # attendre que l'ancien serveur ait fini de se fermer.
                print("ANCIEN TICKET MATCHED ABANDONNE (nouvelle recherche) :", ticket["ticket_id"])
                ticket["status"] = "abandoned"

        ticket_id = uuid4().hex
        ticket: dict[str, Any] = {
            "ticket_id": ticket_id,
            "lobby_id": party["lobby_id"],
            "leader_steam_id": party["leader_steam_id"],
            "mode": party["mode"],
            "members": party["members"],
            "status": "searching",
            "match_id": None,
            "created_at": _now(),
        }
        tickets[ticket_id] = ticket

        opponent = find_compatible_ticket_locked(ticket)

        if opponent is not None:
            print("")
            print("########################################")
            print("MATCH TROUVE")
            print("########################################")
            print("TICKET A :", opponent["ticket_id"], "(", opponent["lobby_id"], ")")
            print("TICKET B :", ticket["ticket_id"], "(", ticket["lobby_id"], ")")
            print("MODE     :", ticket["mode"])

            match = create_match_locked(opponent, ticket)

            opponent["status"] = "matched"
            opponent["match_id"] = match["match_id"]
            ticket["status"] = "matched"
            ticket["match_id"] = match["match_id"]
        else:
            print("TICKET AJOUTE A LA RECHERCHE :", ticket_id)

        return serialize_ticket_locked(ticket)


# =========================================================
# TICKET STATUS (polling)
# =========================================================

@app.get("/matchmaking/ticket/{ticket_id}")
def get_ticket_status(ticket_id: str):

    with _lock:
        prune_locked()

        ticket = tickets.get(ticket_id)

        if ticket is None:
            raise HTTPException(status_code=404, detail="Ticket introuvable")

        return serialize_ticket_locked(ticket)


# =========================================================
# CANCEL SEARCH
# =========================================================

@app.post("/matchmaking/ticket/{ticket_id}/cancel")
def cancel_ticket(ticket_id: str):

    with _lock:
        ticket = tickets.get(ticket_id)

        if ticket is None:
            raise HTTPException(status_code=404, detail="Ticket introuvable")

        if ticket["status"] == "searching":
            ticket["status"] = "cancelled"
            print("TICKET ANNULE :", ticket_id)

        return serialize_ticket_locked(ticket)


# =========================================================
# CUSTOM GAME : SALONS À CODE (façon Among Us)
# =========================================================
#
# Un salon n'a plus rien à voir avec un lobby Steam : n'importe quel joueur
# (ami Steam ou non) peut rejoindre en tapant le code, un peu comme un code
# de partie Among Us. L'identité (steam_id/name) reste transmise par le
# client à chaque appel — il n'y a pas d'authentification serveur au-delà
# de ça, dans le même esprit de confiance que le reste du matchmaking.

def generate_room_code_locked() -> str:
    while True:
        code = "".join(random.choice(ROOM_CODE_ALPHABET) for _ in range(ROOM_CODE_LENGTH))
        if code not in rooms:
            return code


def bump_room_version_locked(room: dict[str, Any]) -> None:
    """Appelé sous _lock à chaque mutation du salon. Le client compare ce
    numéro à la dernière version qu'il a appliquée (settings, poll...) et
    ignore toute réponse plus ancienne : le polling continu (GET toutes les
    1s) et une action (POST settings/team/start) peuvent se terminer dans le
    désordre (latence réseau variable), et sans ce garde une réponse de
    poll "en retard" pouvait écraser un changement pourtant déjà appliqué
    avec l'état d'AVANT ce changement — c'est ce qui donnait l'impression
    que la sélection de map/mode "revenait en arrière" toute seule."""
    room["version"] = room.get("version", 1) + 1
    room["last_activity_at"] = _now()


def serialize_room_locked(room: dict[str, Any]) -> dict[str, Any]:
    result = {
        "code": room["code"],
        "version": room.get("version", 1),
        "host_steam_id": room["host_steam_id"],
        "map": room["map"],
        "mode": room["mode"],
        "random_teams": room["random_teams"],
        "status": room["status"],
        "members": list(room["members"].values()),
    }
    if room.get("server") is not None:
        result["server"] = refresh_server_status_locked(room["server"])
    else:
        result["server"] = None
    return result


@app.post("/rooms")
def create_room(request: CreateRoomRequest):

    with _lock:
        prune_locked()

        code = generate_room_code_locked()
        room: dict[str, Any] = {
            "code": code,
            "host_steam_id": request.steam_id,
            "map": "default",
            "mode": "TEAM",
            "random_teams": False,
            "status": "open",
            "members": {
                request.steam_id: {
                    "steam_id": request.steam_id,
                    "name": request.name,
                    "team": "",
                }
            },
            "server": None,
            "match_id": None,
            "version": 1,
            "created_at": _now(),
            "last_activity_at": _now(),
        }
        rooms[code] = room

        print("")
        print("========================================")
        print("CUSTOM GAME : SALON CREE")
        print("Code :", code)
        print("Host :", request.name, "(", request.steam_id, ")")
        print("========================================")

        return serialize_room_locked(room)


@app.post("/rooms/{code}/join")
def join_room(code: str, request: JoinRoomRequest):

    code = code.strip().upper()

    with _lock:
        room = rooms.get(code)

        if room is None:
            raise HTTPException(status_code=404, detail="Salon introuvable")

        if room["status"] != "open":
            raise HTTPException(status_code=400, detail="La partie a déjà démarré")

        if len(room["members"]) >= 8 and request.steam_id not in room["members"]:
            raise HTTPException(status_code=400, detail="Salon complet")

        room["members"][request.steam_id] = {
            "steam_id": request.steam_id,
            "name": request.name,
            "team": room["members"].get(request.steam_id, {}).get("team", ""),
        }
        bump_room_version_locked(room)

        print("CUSTOM GAME :", request.name, "a rejoint le salon", code)

        return serialize_room_locked(room)


@app.get("/rooms/{code}")
def get_room(code: str):

    code = code.strip().upper()

    with _lock:
        room = rooms.get(code)

        if room is None:
            raise HTTPException(status_code=404, detail="Salon introuvable")

        return serialize_room_locked(room)


@app.post("/rooms/{code}/team")
def set_room_team(code: str, request: RoomTeamRequest):

    code = code.strip().upper()

    with _lock:
        room = rooms.get(code)

        if room is None:
            raise HTTPException(status_code=404, detail="Salon introuvable")

        if request.steam_id not in room["members"]:
            raise HTTPException(status_code=400, detail="Pas dans ce salon")

        if request.team not in ("ASTRAL", "ARCANE", ""):
            raise HTTPException(status_code=400, detail="Camp invalide")

        room["members"][request.steam_id]["team"] = request.team
        bump_room_version_locked(room)

        return serialize_room_locked(room)


@app.post("/rooms/{code}/settings")
def set_room_settings(code: str, request: RoomSettingsRequest):

    code = code.strip().upper()

    with _lock:
        room = rooms.get(code)

        if room is None:
            raise HTTPException(status_code=404, detail="Salon introuvable")

        if request.steam_id != room["host_steam_id"]:
            raise HTTPException(status_code=403, detail="Seul le host peut changer les réglages")

        if request.map is not None:
            if request.map not in ("default", "1v1", "labyrinth", "colosseum", "dungeon"):
                raise HTTPException(status_code=400, detail="Map invalide")
            room["map"] = request.map

        if request.mode is not None:
            if request.mode not in ("TEAM", "FFA", "EXPLORE"):
                raise HTTPException(status_code=400, detail="Mode invalide")
            room["mode"] = request.mode

        if request.random_teams is not None:
            room["random_teams"] = request.random_teams

        bump_room_version_locked(room)

        return serialize_room_locked(room)


@app.post("/rooms/{code}/leave")
def leave_room(code: str, request: RoomLeaveRequest):

    code = code.strip().upper()

    with _lock:
        room = rooms.get(code)

        if room is None:
            return {"status": "ok"}

        room["members"].pop(request.steam_id, None)
        bump_room_version_locked(room)

        if not room["members"]:
            room["status"] = "closed"
        elif request.steam_id == room["host_steam_id"]:
            # Le host part : on promeut le premier membre restant, pour que
            # le salon reste utilisable plutôt que de mourir avec lui.
            room["host_steam_id"] = next(iter(room["members"].keys()))
            print("CUSTOM GAME :", code, ": nouveau host ->", room["host_steam_id"])

        return {"status": "ok"}


@app.post("/rooms/{code}/start")
def start_room(code: str, request: RoomStartRequest):

    code = code.strip().upper()

    with _lock:
        prune_locked()

        room = rooms.get(code)

        if room is None:
            raise HTTPException(status_code=404, detail="Salon introuvable")

        if request.steam_id != room["host_steam_id"]:
            raise HTTPException(status_code=403, detail="Seul le host peut lancer la partie")

        if room["status"] != "open":
            return serialize_room_locked(room)

        members = list(room["members"].values())
        if not members:
            raise HTTPException(status_code=400, detail="Salon vide")

        # Assignation finale des camps : aléatoire si demandé, sinon le choix
        # individuel de chacun (ceux qui n'ont rien choisi partent sur
        # ASTRAL par défaut plutôt que de bloquer le lancement).
        team_assignments: dict[str, str] = {}
        if room["mode"] == "TEAM":
            if room["random_teams"]:
                shuffled = list(members)
                random.shuffle(shuffled)
                for i, member in enumerate(shuffled):
                    team_assignments[member["steam_id"]] = "ASTRAL" if i % 2 == 0 else "ARCANE"
            else:
                for member in members:
                    team_assignments[member["steam_id"]] = member["team"] or "ASTRAL"

        match_id = "AR-" + uuid4().hex[:8].upper()
        if room["mode"] == "FFA":
            server_mode = "CUSTOM DEATHMATCH"
        elif room["mode"] == "EXPLORE":
            server_mode = "CUSTOM EXPLORE"
        else:
            server_mode = "CUSTOM GAME"

        match: dict[str, Any] = {
            "match_id": match_id,
            "game": "ARENA_RIFT",
            "mode": server_mode,
            "status": "starting_server",
            "created_at": _now(),
            "finished_at": None,
            "tickets": [],
            "parties": [{"lobby_id": code, "leader_steam_id": room["host_steam_id"], "members": members}],
            "server": None,
        }
        matches[match_id] = match

        server_result = start_game_server(match_id, room["map"])

        if server_result["status"] == "error":
            match["status"] = "error"
            match["finished_at"] = _now()
            match["server"] = {"status": "error", "error": server_result["error"]}
            room["server"] = match["server"]
            return serialize_room_locked(room)

        match["status"] = "matched"
        match["server"] = {
            "status": "starting",
            "ip": server_result["ip"],
            "port": server_result["port"],
            "pid": server_result["pid"],
        }

        room["status"] = "starting"
        room["match_id"] = match_id
        room["server"] = {
            "status": "starting",
            "ip": server_result["ip"],
            "port": server_result["port"],
            "match_id": match_id,
            "teams": team_assignments,
        }
        bump_room_version_locked(room)

        print("")
        print("########################################")
        print("CUSTOM GAME PRETE")
        print("########################################")
        print("SALON    :", code)
        print("MATCH ID :", match_id)
        print("MODE     :", server_mode)
        print("MAP      :", room["map"])
        print("IP       :", server_result["ip"])
        print("PORT     :", server_result["port"])
        print("########################################")
        print("")

        return serialize_room_locked(room)


# =========================================================
# MATCH LIFECYCLE REPORT (appelé par le serveur de jeu dédié lui-même)
# =========================================================

@app.post("/matches/{match_id}/report")
def report_match_event(match_id: str, report: MatchReport):

    with _lock:
        match = matches.get(match_id)

        if match is None:
            raise HTTPException(status_code=404, detail="Match introuvable")

        if report.event == "ready":
            print("MATCH", match_id, ": SERVEUR PRET")
            if match["server"] is not None:
                match["server"]["status"] = "online"
            match["status"] = "in_progress"

            # Si ce match vient d'un salon Custom Game, on met aussi à jour
            # l'état du salon que les clients pollent — sans ça, le salon
            # restait bloqué sur "starting" indéfiniment.
            for room in rooms.values():
                if room.get("match_id") == match_id and room.get("server") is not None:
                    room["server"]["status"] = "online"
                    room["status"] = "started"
                    bump_room_version_locked(room)

        elif report.event == "finished":
            print("MATCH", match_id, ": TERMINE (rapporté par le serveur de jeu)")
            match["status"] = "finished"
            match["finished_at"] = _now()
            if match["server"] is not None:
                match["server"]["status"] = "stopped"

            for code in list(rooms.keys()):
                room = rooms[code]
                if room.get("match_id") == match_id:
                    room["status"] = "closed"
                    bump_room_version_locked(room)

        else:
            raise HTTPException(status_code=400, detail="Event inconnu : %s" % report.event)

        return {"status": "ok"}


# =========================================================
# MATCH STATUS (debug / consultation directe par match_id)
# =========================================================

@app.get("/match/{match_id}")
def get_match(match_id: str):

    with _lock:
        match = matches.get(match_id)

        if match is None:
            raise HTTPException(status_code=404, detail="Match introuvable")

        match["server"] = refresh_server_status_locked(match.get("server"))

        return match


# =========================================================
# DEBUG
# =========================================================

@app.get("/debug/tickets")
def debug_tickets():

    with _lock:
        prune_locked()

        return {
            "ticket_count": len(tickets),
            "tickets": list(tickets.values())
        }


@app.get("/debug/matches")
def debug_matches():

    with _lock:
        for match in matches.values():
            match["server"] = refresh_server_status_locked(match.get("server"))

        return {
            "match_count": len(matches),
            "matches": list(matches.values())
        }


@app.get("/debug/rooms")
def debug_rooms():

    with _lock:
        prune_locked()

        return {
            "room_count": len(rooms),
            "rooms": [serialize_room_locked(r) for r in rooms.values()]
        }


@app.get("/debug/servers")
def debug_servers():

    result = []

    for port, process in list(game_servers.items()):

        result.append({
            "port": port,
            "pid": process.pid,
            "running": process.poll() is None
        })

    return {
        "server_count": len(result),
        "servers": result
    }
