## Imports
import random
import time
from selenium import webdriver
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.common.by import By
import json
from datetime import datetime


## Parametres
start_date = "2024-10-28"
end_date = "2024-11-01"

start_str = '08:00 AM'
end_str = '11:00 PM'

## Création du driver
def create_driver():
    user_agent_list = [
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/92.0.4515.131 Safari/537.36',
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:90.0) Gecko/20100101 Firefox/90.0',
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 11.5; rv:90.0) Gecko/20100101 Firefox/90.0',
    ]
    user_agent = random.choice(user_agent_list)

    browser_options = Options()
    browser_options.add_argument("--no-sandbox")
    browser_options.add_argument("--headless")
    browser_options.add_argument("--disable-gpu")
    browser_options.add_argument(f'user-agent={user_agent}')
    browser_options.add_argument("--disable-extensions")
    browser_options.add_argument("--disable-application-cache")
    browser_options.add_argument("--disable-infobars")
    #browser_options.add_argument("--disable-dev-shm-usage")
    browser_options.add_argument("--enable-automation")
    prefs = {"profile.managed_default_content_settings.images": 2}
    browser_options.add_experimental_option("prefs", prefs)

    driver_instance = webdriver.Chrome(options=browser_options)

    return driver_instance


## Init

## Init
def initDriver(dateFrom, dateTo):
    try:
        url = 'https://tradingeconomics.com/calendar'
        cookies = [
                {"name": "cal-custom-range", "value": f"{dateFrom}|{dateTo}", "domain": ".tradingeconomics.com"},
                {"name": "calendar-countries", "value": "aus,can,emu,eun,fra,deu,jpn,gbr,usa,wld,che,nzl", "domain": ".tradingeconomics.com"},
                {"name": "cal-timezone-offset", "value": "120", "domain": ".tradingeconomics.com"}
            ]
        print(f"[DEBUG] Initialisation du driver avec les dates {dateFrom} - {dateTo} et l'URL {url}")

        global driver
        driver = create_driver()
        driver.get(url)
        print(f"[DEBUG] URL chargée : {url}")

        [driver.add_cookie(cookie) for cookie in cookies]
        print(f"[DEBUG] Cookies ajoutés : {cookies}")

        # Récupérer les cookies après ajout
        # added_cookies = driver.get_cookies()
        # debug_message(f"[DEBUG] Cookies actuels dans le navigateur : {added_cookies}")

        driver.refresh()
        print("[DEBUG] Page rafraîchie.")

        added_cookies = driver.get_cookies()
        # debug_message(f"[DEBUG] Cookies actuels dans le navigateur : {added_cookies}")

        return True

    except:
        return False

## is_time_in_interval

def is_time_in_interval(time_str):
    start = datetime.strptime(start_str, '%I:%M %p').time()
    end = datetime.strptime(end_str, '%I:%M %p').time()

    time = datetime.strptime(time_str, '%I:%M %p').time()

    return start <= time <= end

## Fonction de scraping des données
def parse_calendar(driver, country_list):
    rows = driver.find_elements(By.XPATH, "//table[@id='calendar']/tbody/tr")
    calendar = []

    for row in rows:
        try:
            event_name = row.find_element(By.CLASS_NAME, "calendar-event").text
            consensus_value = row.find_element(By.ID, "consensus").text

            if not consensus_value:
                print("- Pas de consensus :", event_name)
                continue

            pays = row.find_element(By.CLASS_NAME, "calendar-iso").text

            if pays not in country_list:
                print("- Not in country list")
                continue

            element_date = row.find_element(By.XPATH, ".//td[contains(@class, '2024')]")
            datetime = element_date.get_attribute("class") + " " + element_date.text

            if not(is_time_in_interval(element_date.text)):
                print("- Not in hour range")
                continue

            element_importance = row.find_element(By.XPATH, ".//td//span[contains(@class, 'calendar-date')]")
            importance = element_importance.get_attribute("class")[-1]
            element_href = row.find_element(By.XPATH, ".//td[3]//a")
            href = element_href.get_attribute("href").replace('https://tradingeconomics.com', '')

            print("--- All good.")

            calendar.append([
                datetime,
                pays,
                importance,
                event_name,
                consensus_value,
                href,
                ""
            ])

        except Exception as e:
            # print(f"- Erreur lors du traitement de l'événement : {e}")
            print("- Not a tradable event")
            # a=0

    return calendar

## Main
def main_parse_calendar():

    if(initDriver(start_date, end_date)):

        country_list = ["FR","DE","JP","EA","AU","GB","US","CH","NZ","CA"]
        calendar = []

        calendar = parse_calendar(driver, country_list)
        print(calendar)

        driver.quit()


        return calendar

    else:
        print("[DEBUG] Erreur creation du Driver")
        return "abort/"


if __name__ == "__main__":
    print("---- Debut ----")
    main_parse_calendar()