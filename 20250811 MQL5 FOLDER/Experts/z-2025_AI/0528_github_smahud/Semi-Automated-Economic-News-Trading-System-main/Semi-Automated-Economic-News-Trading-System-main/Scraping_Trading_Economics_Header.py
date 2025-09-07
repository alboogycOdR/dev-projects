## Imports
import socket
import json
import os
import random
import time
import pandas as pd
from selenium import webdriver
import logging
from datetime import datetime
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
from selenium.webdriver.support.ui import WebDriverWait
from selenium.webdriver.support import expected_conditions as EC
from selenium.common.exceptions import TimeoutException
import re
import tkinter as tk
from tkinter import ttk
import webbrowser

## Configuration du logging
log_file_path = '/Users/mathis/Library/Mobile Documents/com~apple~CloudDocs/1- Projets/4- Trading/Semi-Automatic_News_Trading/0- ENC API/Trading Economics/LOG_FILES/log_{}.log'.format(datetime.now().strftime("%Y-%m-%d %H.%M.%S"))

logger = logging.getLogger()
logger.setLevel(logging.ERROR)

# Gestionnaire de fichier pour enregistrer tous les niveaux de log
file_handler = logging.FileHandler(log_file_path)
file_handler.setLevel(logging.ERROR)

formatter = logging.Formatter('%(asctime)s - %(levelname)s - %(message)s')
file_handler.setFormatter(formatter)

logger.addHandler(file_handler)


## Création du driver
def create_driver():
    logger.error("[DEBUG] Création du driver...")
    user_agent_list = [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:90.0) Gecko/20100101 Firefox/90.0',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 11.5; rv:90.0) Gecko/20100101 Firefox/90.0',
    ]
    user_agent = random.choice(user_agent_list)
    logger.error(f"[DEBUG] User Agent utilisé : {user_agent}")

    browser_options = Options()
    browser_options.add_argument("--no-sandbox")
    browser_options.add_argument("--headless")
    browser_options.add_argument("--disable-gpu")
    browser_options.add_argument(f'user-agent={user_agent}')
    browser_options.add_argument("--disable-extensions")
    browser_options.add_argument("--disable-application-cache")
    browser_options.add_argument("--disable-infobars")
    browser_options.add_argument("--enable-automation")
    prefs = {"profile.managed_default_content_settings.images": 2}
    browser_options.add_experimental_option("prefs", prefs)

    driver_instance = webdriver.Chrome(options=browser_options)
    logger.error("[DEBUG] Driver créé.")
    return driver_instance


## Formate data
def extract_number(text):
    # logger.error(f"[DEBUG] Tentative d'extraction de nombre depuis : {text}")
    match = re.search(r'-?\d+(\.\d+)?', text)
    if match:
        number = match.group()
        # logger.error(f"[DEBUG] Nombre extrait : {number}")
        return number
    # logger.error("[DEBUG] Aucun nombre trouvé.")
    return None

## Time functions

def is_time_in_interval(time_str, start_str, end_str):
    start = datetime.strptime(start_str, '%I:%M %p').time()
    end = datetime.strptime(end_str, '%I:%M %p').time()

    time = datetime.strptime(time_str, '%I:%M %p').time()

    return start <= time <= end

def convertTime(date_str):
    dt = datetime.strptime(date_str, "%Y-%m-%d %I:%M %p")
    return dt.strftime("%Y.%m.%d %H:%M:%S")


## Class & fonction
class socketserver:
    def __init__(self, address='', port=9090):
        logger.error(f"[DEBUG] Initialisation du socket serveur avec adresse {address} et port {port}")
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.address = address
        self.port = port
        self.sock.bind((self.address, self.port))
        self.sock.listen(1)
        self.conn = None
        self.addr = None

    def recvmsg(self, handle_main_parse_one_event, handle_main_parse_calendar):
        if self.conn is None:
            logger.error("[DEBUG] Attente d'une connexion...")
            self.conn, self.addr = self.sock.accept()
            logger.error('[DEBUG] Connected to ' + str(self.addr))

        while True:
            logger.error("[DEBUG] En attente de données...")
            cummdata = ''
            data = self.conn.recv(10000)
            if not data:
                logger.error("[DEBUG] Aucune donnée reçue, arrêt de la réception.")
                break
            cummdata += data.decode("utf-8")
            logger.error("[DEBUG] Message reçu de la part de MQL5 : " + str(cummdata.split(",")))

            if cummdata.strip() == "close":
                logger.error("[DEBUG] Message 'close' reçu. Fermeture de la connexion.")
                reponse = "Connection fermee/"
                self.conn.sendall(reponse.encode("utf-8"))
                break

            DateFrom,DateTo,EventName,DataType = cummdata.split(",")

            if DataType == "calendar":
                reponse = handle_main_parse_calendar(DateFrom, DateTo)
                logger.error(f"[DEBUG] Réponse envoyée : {reponse}")
                self.conn.sendall(reponse.encode("utf-8"))

            elif DataType == "actual" or DataType == "previous":
                reponse = handle_main_parse_one_event(DateFrom, EventName, DataType)
                logger.error(f"[DEBUG] Réponse envoyée : {reponse}")
                self.conn.sendall(reponse.encode("utf-8"))

        self.close_connection()
        return cummdata

    def close_connection(self):
        if self.conn:
            logger.error("[DEBUG] Fermeture de la connexion client.")
            self.conn.close()
            logger.error("[DEBUG] Connexion client fermée.")
            self.conn = None

    def __del__(self):
        logger.error("[DEBUG] Destruction de l'objet socket, fermeture de la socket.")
        self.sock.close()


##

class EconomicCalendarApp:
    def __init__(self, root, events, consensusBrut, previousBrut, lien):
        self.root = root
        self.root.title("Événements du calendrier économique")

        self.consensusBrut = consensusBrut
        self.lien = lien
        self.previousBrut = previousBrut

        headers = ['Datetime', 'Pays', 'Importance', 'Event', 'Consensus', 'Href', 'Impact']

        df = pd.DataFrame(events, columns=headers)

        # Convertir en liste de dictionnaires
        self.data = df.to_dict(orient='records')

        # Stockage des cases cochées et entrées modifiées
        self.checked_vars = []
        self.impact_entries = []

        # Créer un conteneur Canvas pour activer le défilement
        self.canvas = tk.Canvas(self.root)
        self.canvas.pack(side="left", fill="both", expand=True)

        # Ajouter une barre de défilement verticale
        self.scrollbar = tk.Scrollbar(self.root, orient="vertical", command=self.canvas.yview)
        self.scrollbar.pack(side="right", fill="y")
        self.canvas.configure(yscrollcommand=self.scrollbar.set)

        # Ajouter un frame dans le canvas pour contenir le tableau
        self.table_frame = tk.Frame(self.canvas)
        self.canvas.create_window((0, 0), window=self.table_frame, anchor="nw")

        # Créer l'en-tête du tableau
        self.create_table_header()

        # Ajouter les lignes et les cases à cocher
        self.populate_table()

        # Ajuster la taille du canvas pour correspondre au contenu
        self.table_frame.update_idletasks()
        self.canvas.config(scrollregion=self.canvas.bbox("all"))

        # Bouton pour enregistrer et fermer
        save_button = tk.Button(self.root, text="Enregistrer", command=self.save)
        save_button.pack(pady=10)

        # Variable pour stocker les lignes sélectionnées
        self.selected_rows = []

    def create_table_header(self):
        # En-têtes
        headers = ["", "Impact", "Datetime", "Pays","Importance","Event", "Consensus", "Previous", "Href"]
        for idx, header in enumerate(headers):
            label = tk.Label(self.table_frame, text=header, borderwidth=1, relief="solid")
            label.grid(row=0, column=idx, sticky="nsew")

    def open_link(self, url):
        webbrowser.open(url)

    def populate_table(self):
        # Définir les couleurs pour l'alternance
        row_colors = ["#2a2a2a", "#000000"]  # Gris et noir
        current_color_index = 0  # Indicateur de la couleur actuelle
        previous_datetime = None  # Variable pour stocker le datetime précédent

        # Ajouter les données et les boutons de sélection
        for i, item in enumerate(self.data):
            # Vérifier si le datetime a changé
            if item["Datetime"] != previous_datetime:
                current_color_index = 1 - current_color_index  # Alterner l'indice de couleur
                previous_datetime = item["Datetime"]

            # Couleur de fond de la ligne
            row_bg_color = row_colors[current_color_index]

            # Créer une variable pour suivre l'état de la case à cocher
            checked_var = tk.BooleanVar()
            self.checked_vars.append(checked_var)

            # Ajouter la case à cocher
            check_button = tk.Checkbutton(self.table_frame, variable=checked_var, bg=row_bg_color)
            check_button.grid(row=i+1, column=0, sticky="nsew")

            # Ajouter les autres colonnes avec la couleur de fond de la ligne
            tk.Label(self.table_frame, text=item["Datetime"], borderwidth=1, relief="solid",
                    bg=row_bg_color, fg="white").grid(row=i+1, column=2, sticky="nsew")
            tk.Label(self.table_frame, text=item["Pays"], borderwidth=1, relief="solid",
                    bg=row_bg_color, fg="white").grid(row=i+1, column=3, sticky="nsew")
            tk.Label(self.table_frame, text=item["Event"], borderwidth=1, relief="solid",
                    bg=row_bg_color, fg="white").grid(row=i+1, column=5, sticky="nsew")
            tk.Label(self.table_frame, text=self.consensusBrut[i], borderwidth=1, relief="solid",
                    bg=row_bg_color, fg="white").grid(row=i+1, column=6, sticky="nsew")
            tk.Label(self.table_frame, text=self.previousBrut[i], borderwidth=1, relief="solid",
                    bg=row_bg_color, fg="white").grid(row=i+1, column=7, sticky="nsew")

            # Définir la couleur en fonction de l'importance
            importance_color = {
                "3": "red",
                "2": "orange",
                "1": "green"
            }
            importance_bg = importance_color.get(item["Importance"], row_bg_color)
            tk.Label(self.table_frame, text=item["Importance"], borderwidth=1, relief="solid",
                    bg=importance_bg, fg="white").grid(row=i+1, column=4, sticky="nsew")

            # Créer un label cliquable pour le lien
            href_label = tk.Label(self.table_frame, text=item["Href"], fg="blue", cursor="hand2",
                                  bg=row_bg_color)
            href_label.grid(row=i+1, column=8, sticky="nsew")
            href_label.bind("<Button-1>", lambda e, url=self.lien[i]: self.open_link(url))

            # Champ modifiable pour la colonne Impact
            impact_entry = tk.Entry(self.table_frame, bg=row_bg_color, fg="white", width=5)
            impact_entry.grid(row=i+1, column=1, sticky="nsew")
            impact_entry.insert(0, item["Impact"])  # Valeur initiale vide (ou déjà définie)
            self.impact_entries.append(impact_entry)

    def save(self):
        self.selected_rows = []
        # Récupérer les lignes sélectionnées
        for i, checked_var in enumerate(self.checked_vars):
            if checked_var.get():  # Si la case est cochée
                # Mettre à jour l'impact dans les données
                self.data[i]["Impact"] = self.impact_entries[i].get()
                self.selected_rows.append(self.data[i])