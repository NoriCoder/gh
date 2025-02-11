import json,sqlite3,os,sys,requests,subprocess,sqlite3,time,datetime,threading,shutil,logging,threading,multiprocessing,sys,gspread
from urllib.parse import urlparse, parse_qs
from flask import Flask, request, jsonify
from colorama import Fore
from time import sleep
from concurrent.futures import ThreadPoolExecutor
SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
CONFIG_FILE = os.path.join(SCRIPT_DIR, "config.json")
count_tabs = 0

def find_roblox_data_paths():
    count = 0
    base_path = "/data/data"
    paths = []
    for folder in os.listdir(base_path):
        if count < count_tabs:
            if folder.startswith("com.roblox.") and folder != 'com.roblox.client':
                path = os.path.join(base_path, folder, "files/appData/LocalStorage/appStorage.json")
                if not os.path.isfile(path):
                    subprocess.run(['am', 'start', '-a', 'android.intent.action.VIEW', '-d', 'roblox://placeID=', folder])
                    sleep(5)
                    force_roblox(folder)
                paths.append(path)
                count += 1
        else:
            break
    return paths

def getPackageRoblox():
    base_path = "/data/data"
    packages = []
    for folder in os.listdir(base_path):
        if folder.startswith("com.roblox.") and folder != 'com.roblox.client':
            packages.append(folder)
    return packages

def current_time():
    if int(datetime.datetime.now().strftime('%I')) < 12 and datetime.datetime.now().strftime('%p') == 'PM':
        hours = int(datetime.datetime.now().strftime('%I')) + 12
        return str(hours) + datetime.datetime.now().strftime(':%M:%S')
    elif datetime.datetime.now().strftime('%I') == '12' and datetime.datetime.now().strftime('%p') == 'AM':
        hours = int(datetime.datetime.now().strftime('%I')) + 12
        return str(hours) + datetime.datetime.now().strftime(':%M:%S')
    else:
        return datetime.datetime.now().strftime('%I:%M:%S')

def read_roblox_data(data_path, retries=3):
    attempt = 0
    while attempt < retries:
        try:
            with open(data_path, 'r') as file:
                data = json.load(file)
                user_id = data.get("UserId")
                username = data.get("Username")
                if user_id is not None and username is not None:
                    return user_id, username
                else:
                    attempt += 1
        except Exception as e:
            attempt += 1
            time.sleep(1)

    return False, False

def check_online(userid):
    data = {
        "userIds": [userid]
    }
    headers = {'Content-Type': 'application/json'}
    try:
        response = requests.post('https://presence.roblox.com/v1/presence/users', data=json.dumps(data), headers=headers, timeout=5)
        ress = response.json()
        if 'userPresences' in ress:
            if ress['userPresences'][0]['lastLocation'] == 'Website':
                return True
            else:
                return False
        else:
            return False
    except Exception:
        
        return False
    
    
def extract_private_server_code(link):
    try:
        parsed_url = urlparse(link)
        query_params = parse_qs(parsed_url.query)
        if 'share' in parsed_url.path and 'code' in query_params:
            return query_params['code'][0]
        if 'privateServerLinkCode' in query_params:
            return query_params['privateServerLinkCode'][0]
        else:
            return link
    except Exception as e:
        return None
    

def launch_roblox(roblox_package, placeid, psserver):
    try:
        full_command = f"pkill -f {roblox_package}"
        
        process = subprocess.Popen(
            full_command,
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE
        )
        
        stdout, stderr = process.communicate(timeout=10)
    except subprocess.CalledProcessError as e:
        pass
    except Exception as e:
        pass
    time.sleep(3)

    try:
        subprocess.run(
            f'am start -a android.intent.action.VIEW -d roblox://placeID= {roblox_package}',
            check=True,
            timeout=10,
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        time.sleep(5)

        if psserver != '':
            pslink = extract_private_server_code(psserver)
            viplink = f"https://www.roblox.com/games/{placeid}?privateServerLinkCode={pslink}"
            user_command = f'am start -S -a android.intent.action.VIEW -d "{viplink}" {roblox_package}'
        else:
            user_command = f'am start -S -a android.intent.action.VIEW -d roblox://placeID={placeid} {roblox_package}'
        subprocess.run(
            user_command,
            check=True,
            timeout=10,
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )

    except subprocess.TimeoutExpired:
        pass
    except subprocess.CalledProcessError as e:
        pass
    except Exception as e:
        print(e)

def localhost():
    app = Flask(__name__)

    log = logging.getLogger('werkzeug')
    log.setLevel(logging.ERROR)

    sys.stdout = open(os.devnull, 'w')
    sys.stderr = open(os.devnull, 'w')

    data_store = []
    rejoin_requests = []

    @app.route('/updatetime', methods=['POST'])
    def update_time():
        if request.headers.get('Content-Type') != 'application/json':
            return jsonify({'message': 'Invalid Content-Type'}), 400
        
        data = request.get_json()
        if 'username' not in data:
            return jsonify({'message': 'Missing username'}), 400
        
        username = data['username']
        current_time = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        user_found = False
        for item in data_store:
            if item['username'] == username:
                item['lastUpdated'] = current_time
                user_found = True
                break
        
        if not user_found:
            data_store.append({'username': username, 'lastUpdated': current_time})
        
        response = {
            'status': 'success',
            'message': f'Update Time For {username} Success'
        }
        
        return jsonify(response), 200

    @app.route('/updatetime/data', methods=['GET'])
    def get_data():
        current_time = datetime.datetime.now()
        
        data_with_timeout = []
        for item in data_store:
            last_updated = datetime.datetime.strptime(item['lastUpdated'], '%Y-%m-%d %H:%M:%S')
            timeout = int((current_time - last_updated).total_seconds())  # Lấy số nguyên
            item_with_timeout = item.copy()
            item_with_timeout['timeout'] = timeout
            data_with_timeout.append(item_with_timeout)
        
        response = {
            'status': 'success',
            'data': data_with_timeout
        }
        
        return jsonify(response), 200

    @app.route('/rejoin', methods=['POST'])
    def rejoin_roblox():
        if request.headers.get('Content-Type') != 'application/json':
            return jsonify({'message': 'Invalid Content-Type'}), 400
        
        data = request.get_json()
        if 'username' not in data:
            return jsonify({'message': 'Missing username'}), 400
        
        username = data['username']
        current_time = datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')
        
        rejoin_requests.append({'username': username, 'time': current_time})
        
        response = {
            'status': 'success',
            'username': username,
            'time': current_time
        }
        
        return jsonify(response), 200

    @app.route('/rejoin/requests', methods=['GET'])
    def get_rejoin_requests():
        response_data = rejoin_requests.copy()

        response = {
            'status': 'success',
            'data': response_data
        }
        
        rejoin_requests.clear()
        return jsonify(response), 200

    app.run(debug=False, port=6969)

def updateData():
    sleep(100)
    while True:
        data_sheet = read_sheet()
        for data in data_sheet:
            if device == data['Device']:
                version = data['Version']
                setting = data['Settings']
                with open(CONFIG_FILE, 'r') as f:
                    config = json.load(f)
                if setting:
                    scripts, placeid, psserver = load_setting(setting)
                    importData(scripts)

                if version != config['Version']:
                    printText('Found Version New', 'new')
                    packages = getPackageRoblox()
                    if packages:
                        printText('Packages Roblox Found. Uninstalling...', 'noti')
                        for package in packages:
                            package = package.strip()
                            subprocess.run(['su', '-c', f'pm uninstall {package}'])
                        printText('Uninstall Success', 'success')
                    else:
                        printText('Dont Have Packages Roblox', 'fail')
                            
                    downloadRoblox(True)
                    with open(CONFIG_FILE, 'w', encoding="utf-8") as f:
                        f.write(json.dumps(data, ensure_ascii=False))

def main(setting):
    if setting:
        scripts, placeid, psserver = load_setting(setting)
        importData(scripts)

    count = 0
    while True:
        roblox_paths = find_roblox_data_paths()
        if not roblox_paths:
            print("No Roblox accounts found.")
            sleep(30)
            continue
        for data_path in roblox_paths:
            userid, username = read_roblox_data(data_path)
            if userid and username:
                roblox_package = data_path.split(os.sep)[3]
                
                if count < len(roblox_paths):
                    print(f'{Fore.RESET}[{Fore.CYAN}{current_time()}{Fore.RESET}] {Fore.YELLOW}{username} {Fore.RESET}| {Fore.LIGHTBLACK_EX}Start Launch Tab {Fore.RESET}')
                    launch_roblox(roblox_package, placeid, psserver)
                    sleep(10)
                    count += 1
                else:
                    status = check_online(userid)
                    if status is True and username:
                        print(f'{Fore.RESET}[{Fore.CYAN}{current_time()}{Fore.RESET}] {Fore.YELLOW}{username} {Fore.RED}Is Offline {Fore.RESET}| {Fore.LIGHTBLUE_EX}Relaunch Tab {Fore.RESET}')
                        launch_roblox(roblox_package, placeid, psserver)
                        sleep(10)

        time.sleep(30)

def force_roblox(packages):
    try:
        full_command = f"pkill -f {packages}"
        subprocess.run(
            full_command,
            check=True,
            timeout=10,
            shell=True,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
    except subprocess.TimeoutExpired:
        pass
    except subprocess.CalledProcessError as e:
        pass
    time.sleep(1)

def logout_roblox():
    global logged_in_usernames
    roblox_paths = find_roblox_data_paths()
    if not roblox_paths:
        print("No Roblox accounts found.")
        return

    accounts = []
    print("Available Roblox accounts:")
    for i, data_path in enumerate(roblox_paths, start=1):
        userid, username = read_roblox_data(data_path)
        if userid and username:
            accounts.append((userid, username, data_path))
            print(f"{i}. Username: {username}, UserId: {userid}")

    if not accounts:
        print("No Roblox accounts found.")
        return

    print("Enter the number of the account to log out, '0' to log out all accounts, or 'q' to quit:")
    choice = input().strip()
    if choice.lower() == 'q':
        return

    try:
        if choice == '0':
            for userid, username, data_path in accounts:
                try:
                    roblox_package = data_path.split(os.sep)[3]
                    force_roblox(roblox_package)
                    appstorage_path = os.path.join(data_path)
                    print(f"Logging out account: {username}, path: {appstorage_path}")
                    os.remove(appstorage_path)
                    try:
                        logged_in_usernames.remove(username)
                    except:
                        pass
                    print(f"Logged out account: {username}")
                except:
                    pass
        else:
            choice_index = int(choice) - 1
            if 0 <= choice_index < len(accounts):
                userid, username, data_path = accounts[choice_index]
                roblox_package = data_path.split(os.sep)[3]
                force_roblox(roblox_package)
                appstorage_path = os.path.join(data_path)
                print(f"Logging out account: {username}, path: {appstorage_path}")
                os.remove(appstorage_path)
                try:
                    logged_in_usernames.remove(username)
                except:
                    pass
                print(f"Logged out account: {username}")
            else:
                print("Invalid choice. Choice index out of range.")
    except ValueError:
        print("Invalid input. Please enter a number.")
    except Exception as e:
        import traceback
        traceback.print_exc()
        print(f"Error: {e}")

logged_in_usernames = set()
def fetch_valid_cookie(cookie_file, usernames):
    global logged_in_usernames
    try:
        with open(cookie_file, 'r') as file:
            cookies = file.readlines()

        for cookie in cookies:
            cookie = cookie.strip()
            response = requests.get(
                'https://users.roblox.com/v1/users/authenticated',
                cookies={'.ROBLOSECURITY': cookie},
                timeout=5
            )
            if response.status_code == 200:
                name = response.json()['name']
                userid = response.json()['id']
                if name not in usernames and name not in logged_in_usernames:
                    return cookie, name, userid
        return None, None, None
    except Exception as e:
        print(f"Error fetching valid cookie: {e}")
        return None, None, None
    
def findotherrobloxdatapath():
    base_path = "/data/data"
    paths = []
    print("Scanning base path:", base_path)

    for folder in os.listdir(base_path):
        if folder.lower().startswith("com.roblox.") and folder != 'com.roblox.client':
            localstorage_path = os.path.join(base_path, folder, "files/appData/LocalStorage")
            if os.path.isdir(localstorage_path):
                paths.append(localstorage_path)
    return paths

def update_cookies_db(cookie_value):
    try:
        # Path to the template Cookies.db file
        template_cookies_db_path = os.path.join(SCRIPT_DIR, "Cookies.db")
        conn = sqlite3.connect(template_cookies_db_path)
        cursor = conn.cursor()
        cursor.execute("UPDATE Cookies SET value=? WHERE name='.ROBLOSECURITY'", (cookie_value.strip(),))
        conn.commit()
        conn.close()
    except Exception as e:
        print(f"Error updating Cookies.db: {e}")

def set_permissions(file_path, mode):
    try:
        os.chmod(file_path, mode)
        print(f"Permissions set to {oct(mode)} for {file_path}")
    except Exception as e:
        print(f"Error setting permissions for {file_path}: {e}")

def login_roblox():
    global logged_in_usernames
    roblox_paths = findotherrobloxdatapath()
    if not roblox_paths:
        print("No Roblox directories found.")
        return


    usernames = []
    paths_to_update = []

    for data_path in roblox_paths:
        appstorage_path = os.path.join(data_path, "appStorage.json")
        if os.path.isfile(appstorage_path):
            userid, username = read_roblox_data(appstorage_path)
            if userid and username:
                logged_in_usernames.add(username)
                usernames.append(username)
            else:
                paths_to_update.append(data_path)
        else:
            paths_to_update.append(data_path)

    COOKIE_FILE = os.path.join(SCRIPT_DIR, "cookie.txt")
    any_logged_in = False
    for data_path in paths_to_update:
        cookie_value, username, userid = fetch_valid_cookie(COOKIE_FILE, usernames)
        if cookie_value and username and userid:
            try:
                roblox_package = data_path.split(os.sep)[3]
                force_roblox(roblox_package)
                print(f"Updating for package: {roblox_package}")
                update_cookies_db(cookie_value)
                target_cookies_db_dir = os.path.join("/data/data", roblox_package, "app_webview/Default")
                target_cookies_db_path = os.path.join(target_cookies_db_dir, "Cookies")
                try:
                    os.remove(target_cookies_db_path)
                except:
                    pass
                subprocess.run(["cp",'-p', os.path.join(SCRIPT_DIR, "Cookies.db"), target_cookies_db_path])
                localstorage_path = data_path
                appstorage_path = os.path.join(localstorage_path, "appStorage.json")
                APPSTORAGE_TEMPLATE = os.path.join(SCRIPT_DIR, "appStorage.json")
                try:
                    os.remove(appstorage_path)
                except:
                    pass
                subprocess.run(["cp", '-p',APPSTORAGE_TEMPLATE, appstorage_path])
                with open(appstorage_path, 'r+') as file:
                    data = json.load(file)
                    data['UserId'] = str(userid)
                    data['Username'] = str(username)
                    file.seek(0)
                    json.dump(data, file)
                    file.truncate()
                any_logged_in= True
                logged_in_usernames.add(username)
                print(f"Logged in account: {username}")
            except Exception as e:
                print(f"Error logging in: {e}")
        else:
            print("No valid cookie found.")
    if not any_logged_in:
        print("No paths could be logged in.")
def find_autoexec_dirs(base_dir='/storage/emulated/0/Android/data'):
    autoexec_dirs = []
    for folder in os.listdir(base_dir):
        if folder.startswith("com.roblox.") and folder != 'com.roblox.client':
            roblox_dir = os.path.join(base_dir, folder)
            fluxus_dir = os.path.join(roblox_dir, 'files/Fluxus/Autoexec')
            delta_dir = os.path.join(roblox_dir, 'files/Delta/autoexec')

            if os.path.exists(fluxus_dir):
                autoexec_dirs.append(fluxus_dir)
            if os.path.exists(delta_dir):
                autoexec_dirs.append(delta_dir)
    return autoexec_dirs


# def find_autoexec_dirs_ArcCodex(base_dir='/storage/emulated/0/'):
#     autoexec_dirs = []
#     for i in range(1, tab+1):
#         i = str(i)
#         autoexec_dir_new_arc = os.path.join(base_dir, f'RobloxClone00{i}', 'Arceus X/Autoexec')
#         autoexec_dir_new_codex = os.path.join(base_dir, f'RobloxClone00{i}', 'Codex/Autoexec')
#         os.makedirs(autoexec_dir_new_arc, exist_ok=True)
#         os.makedirs(autoexec_dir_new_codex, exist_ok=True)
#         if os.path.exists(autoexec_dir_new_arc):
#             autoexec_dirs.append(autoexec_dir_new_arc)
#         if os.path.exists(autoexec_dir_new_codex):
#             autoexec_dirs.append(autoexec_dir_new_codex)
#     return autoexec_dirs

def setup_autoexec_folder():
    SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
    copysos = os.path.join(SCRIPT_DIR, 'autoexec')
    
    # Tạo thư mục nếu nó không tồn tại
    if not os.path.exists(copysos):
        os.makedirs(copysos)
        

    # autoexec_dirs = find_autoexec_dirs()

    # if not autoexec_dirs:
    #     autoexec_dirs = find_autoexec_dirs_ArcCodex()

    #for idx, dir in enumerate(autoexec_dirs, start=1):
        #print(f"{idx}. {dir}")

    #choice = input("Enter the number of the folder to copy files to, or 0 to copy to all: ").strip()

    try:
        # if choice == '0':
        #     for dir in autoexec_dirs:
        #         copy_files(copysos, dir)
        # else:
        #     selected_idx = int(choice) - 1
        #     if 0 <= selected_idx < len(autoexec_dirs):
        #         copy_files(copysos, autoexec_dirs[selected_idx])
        #     else:
        #         print("Invalid choice.")
        #         return
        #copy_files(copysos, '/storage/emulated/0/Delta/Autoexecute')
        print("Files copied successfully.")
    except Exception as e:
        print(f"An error occurred while copying files: {e}")

def find_workspace_dirs(base_dir='/storage/emulated/0/Android/data'):
    workspace_dirs = []
    for folder in os.listdir(base_dir):
        if folder.startswith("com.roblox.") and folder != 'com.roblox.client':
            roblox_dir = os.path.join(base_dir, folder)
            fluxus_dir = os.path.join(roblox_dir, 'files/Fluxus/Workspace')
            delta_dir = os.path.join(roblox_dir, 'files/Delta/Workspace')

            if os.path.exists(fluxus_dir):
                workspace_dirs.append(fluxus_dir)
            if os.path.exists(delta_dir):
                workspace_dirs.append(delta_dir)
    return workspace_dirs

# def find_workspace_dirs_ArcCodex(base_dir='/storage/emulated/0/'):
#     workspace_dirs = []
#     for i in range(1, tab+1):
#         i = str(i)
#         workspace_dir_new_arc = os.path.join(base_dir, f'RobloxClone00{i}', 'Arceus X/Workspace')
#         workspace_dir_new_codex = os.path.join(base_dir, f'RobloxClone00{i}', 'Codex/Workspace')
#         os.makedirs(workspace_dir_new_arc, exist_ok=True)
#         os.makedirs(workspace_dir_new_codex, exist_ok=True)
#         if os.path.exists(workspace_dir_new_arc):
#             workspace_dirs.append(workspace_dir_new_arc)
#         if os.path.exists(workspace_dir_new_codex):
#             workspace_dirs.append(workspace_dir_new_codex)
#     return workspace_dirs

def setup_workspace_folder():
    SCRIPT_DIR = os.path.dirname(os.path.realpath(__file__))
    copysos = os.path.join(SCRIPT_DIR, 'workspace')

    # workspace_dirs = find_workspace_dirs()

    # if not workspace_dirs:
    #     workspace_dirs = find_workspace_dirs_ArcCodex()
    # for idx, dir in enumerate(workspace_dirs, start=1):
    #     print(f"{idx}. {dir}")

    # choice = input("Enter the number of the folder to copy files to, or 0 to copy to all: ").strip()

    try:
        # if choice == '0':
        #     for dir in workspace_dirs:
        #         copy_files2(copysos, dir)
        # else:
        #     selected_idx = int(choice) - 1
        #     if 0 <= selected_idx < len(workspace_dirs):
        #         copy_files2(copysos, workspace_dirs[selected_idx])
        #     else:
        #         print("Invalid choice.")
        #         return
        copy_files2(copysos, '/storage/emulated/0/Delta/Workspace')
        print("Files copied successfully.")
    except Exception as e:
        print(f"An error occurred while copying files: {e}")

def copy_folder(source_dir, target_dir):
    os.makedirs(target_dir, exist_ok=True)

    try:
        if os.path.exists(target_dir):
            shutil.rmtree(target_dir)
        
        shutil.copytree(source_dir, target_dir)
    except Exception as e:
        print(f"An error occurred while copying files: {e}")

def copy_files2(source_dir, target_dir):
    try:
        for item in os.listdir(source_dir):
            source_item = os.path.join(source_dir, item)
            target_item = os.path.join(target_dir, item)
            if os.path.isdir(source_item):
                if os.path.exists(target_item):
                    shutil.rmtree(target_item)
                shutil.copytree(source_item, target_item)
            else:
                shutil.copy2(source_item, target_item)
    except Exception as e:
        print(f"An error occurred while copying files: {e}")

def requestData(url, method, data = None, headers = None):
    if method == 'POST':
        response = requests.post(url, data=data, headers=headers, timeout=10)
    elif method == 'GET':
        response = requests.get(url, timeout=10)
    if response.status_code == 200:
        return response.text
    else:
        return None

def load_setting(type):
    scripts = {'autoexec': [], 'workspace': []}
    psserver = ''
    if type == 'ttd':
        placeid = '13775256536'
        script = requestData('https://pastefy.app/dIA2Qjf9/raw', 'GET')
        if script:
            scripts['autoexec'].append(script)
        else:
            print(f'{Fore.RED}Get Script Failed {Fore.RESET}')

    scriptRejoin = requestData('https://pastefy.app/jepJ8Wfq/raw', 'GET')
    if scriptRejoin:
        scripts['autoexec'].append(scriptRejoin)
    else:
        print(f'{Fore.RED}Get Script Failed {Fore.RESET}')

    return scripts, placeid, psserver

def downloadRoblox(statusUpdate=None):
    base_path = "/data/data"
    data_path = os.path.join(SCRIPT_DIR, 'Roblox.zip')
    count_tabs_current = count_tabs
    count = 0

    if not os.path.exists(data_path) or (os.path.exists(data_path) and statusUpdate):
        if os.path.exists(data_path):
            shutil.rmtree(data_path)

        file_id = requestData('https://pastefy.app/PI8MObN4/raw', 'GET')
        if file_id:
            printText('Roblox Multi Tabs Downloading...', 'noti')
            subprocess.run(["gdown", "--no-cookies", "--continue", f"https://drive.google.com/uc?id={file_id}"])
            printText('Download Success', 'success')

            printText('Unzipping File...', 'noti')
            subprocess.run(["unzip", "-o" 'Roblox.zip'])
            printText('Unzip File Done', 'success')

            printText('Scan Roblox -> Installing...', 'new')
            packages = getPackageRoblox()
            if packages:
                print(f'{len(packages)} Packages Roblox Found', 'noti')
                count_tabs_current = count_tabs - len(packages)

            for folder in os.listdir(SCRIPT_DIR):
                if count < count_tabs_current:
                    if folder.startswith("com.roblox.") and folder not in packages:
                        printText(f'Find Package {folder}', 'noti')
                        folder_path = os.path.join(SCRIPT_DIR, folder)
                        if os.path.isdir(folder_path):
                            for item in os.listdir(folder_path):
                                item_path = os.path.join(folder_path, item)
                                if item.endswith(".apk"):
                                    subprocess.run(['su', '-c', f'pm install {item_path}'])
                                    printText(f'Install {folder} Success', 'success')

                                if os.path.isdir(item_path):
                                    target_path = os.path.join(base_path, folder)
                                    copy_folder(item_path, target_path)
                                    printText(f'Setup {folder} Success', 'success')
                                count += 1
                else:
                    break

        else:
            printText('Get file_id Failed', 'fail')

def downloadRequire():
    data_path = os.path.join(SCRIPT_DIR, 'DataTool.zip')

    while True:
        try:
            if not os.path.exists(data_path):
                printText('Data Downloading...', 'noti')
                subprocess.run(["gdown", "--no-cookies", "--continue", f"https://drive.google.com/uc?id=1wedCg78qGhhAmDvAs7LgcwP9vI1By9FR"])
                printText('Download Success', 'success')

            printText('Unzipping File...', 'noti')
            subprocess.run(["unzip", "-o" 'Roblox.zip'])
            printText('Unzip File Done', 'success')      
            break
        except Exception as e:
            printText(e, 'fail')
            if os.path.exists(data_path):
                shutil.rmtree(data_path)
            continue
        

def importData(scripts):
    count = 1
    executorPath = os.path.join(SCRIPT_DIR, 'Codex')
    pathAutoexec = os.path.join(executorPath, 'Autoexec')
    pathWorkspace = os.path.join(executorPath, 'Workspace')

    scripts = scripts.strip()
    if scripts['autoexec']:
        if os.path.isdir(pathAutoexec):
            shutil.rmtree(pathAutoexec)
            sleep(1)
            os.makedirs(pathAutoexec, exist_ok=True)

        for index, script in enumerate(scripts['autoexec']):
            pathScript = os.path.join(pathAutoexec, f'{index}.txt')
            with open(pathScript, 'w') as f:
                f.write(script)
    if scripts['workspace']:
        if os.path.isdir(pathWorkspace):
            shutil.rmtree(pathWorkspace)
            sleep(1)
            os.makedirs(pathWorkspace, exist_ok=True)

        for index, script in enumerate(scripts['workspace']):
            pathData = os.path.join(pathWorkspace, f'{index}.txt')
            with open(pathData, 'w') as f:
                f.write(script)

    for _ in range(10):
        if count < count_tabs + 1:
            pathMultiTabs = os.path.join(SCRIPT_DIR, f'RobloxClone00{count}', 'Codex')
            if os.path.isdir(pathMultiTabs):
                shutil.rmtree(pathMultiTabs)
            copy_folder(executorPath, pathMultiTabs)
            count += 1
        else:
            break

def printText(text, type):
    if type == 'noti':
        print(f'{Fore.RESET}[{Fore.CYAN}{current_time()}{Fore.RESET}] {Fore.YELLOW} {text} {Fore.RESET}')
    elif type == 'new':
        print(f'{Fore.RESET}[{Fore.CYAN}{current_time()}{Fore.RESET}] {Fore.BLUE} {text} {Fore.RESET}')
    elif type == 'success':
        print(f'{Fore.RESET}[{Fore.CYAN}{current_time()}{Fore.RESET}] {Fore.GREEN} {text} {Fore.RESET}')
    elif type == 'fail':
        print(f'{Fore.RESET}[{Fore.CYAN}{current_time()}{Fore.RESET}] {Fore.RED} {text} {Fore.RESET}')

def read_sheet():
    service_account_file = os.path.join(SCRIPT_DIR, 'ugphone.json')
    gc = gspread.service_account(filename=service_account_file)

    spreadsheet_id = "1Bzux-ufKj4n0jAwhubTf-vQLdbN7xNFesfpY5FnXVko"
    spreadsheet = gc.open_by_key(spreadsheet_id)
    sheet = spreadsheet.sheet1

    return sheet.get_all_records()

if __name__ == "__main__":
    while True:
        try:
            message = r"""  
  _____ _             _   _               ____       _       _       
 |  ___| | ___   __ _| |_(_)_ __   __ _  |  _ \ ___ (_) ___ (_)_ __  
 | |_  | |/ _ \ / _` | __| | '_ \ / _` | | |_) / _ \| |/ _ \| | '_ \ 
 |  _| | | (_) | (_| | |_| | | | | (_| | |  _ <  __/| | (_) | | | | |
 |_|   |_|\___/ \__,_|\__|_|_| |_|\__, | |_| \_\___|/ |\___/|_|_| |_|
                                  |___/           |__/
"""
            os.system('clear')
            print(message)
            print('')
            if len(sys.argv) > 1:
                values = sys.argv[1:]
                device = values[0]

                #python main.py UVIP13
                data_sheet = read_sheet()
                for data in data_sheet:
                    if device == data['Device']:
                        version = data['Version']
                        setting = data['Settings']
                        webhook = data['Webhook']
                        count_tabs = data['Tabs']
                        listFarm = data['List Farm'].split(", ")
                        with open(CONFIG_FILE, 'w', encoding="utf-8") as f:
                            f.write(json.dumps(data, ensure_ascii=False))

                        packages = getPackageRoblox()
                        if not packages or len(packages) < count_tabs:
                            downloadRoblox(True)
                            
                        if not os.path.exists(os.path.join(SCRIPT_DIR, "Cookies.db")):
                            downloadRequire()

                        flask_process = multiprocessing.Process(target=localhost)
                        relaunch_process = multiprocessing.Process(target=main, args=setting)
                        #update_process = multiprocessing.Process(target=updateData)

                        flask_process.start()
                        relaunch_process.start()
                        #update_process.start()
                        
                        flask_process.join()
                        relaunch_process.join()
                        #update_process.join()
            else:
                #setup lại nếu cần thiết
                print(f'{Fore.RED}Input Name Device {Fore.RESET}')
                exit()

        except Exception as e:
            print(e)
