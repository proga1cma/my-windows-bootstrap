# bootstrap_level1.ps1
# Разместить в: https://github.com/proga1cma/my-windows-bootstrap/blob/main/bootstrap_level1.ps1
# Команда для запуска (PowerShell от Администратора):
# Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://raw.githubusercontent.com/proga1cma/my-windows-bootstrap/main/bootstrap_level1.ps1'))

<#
.SYNOPSIS
    Загрузчик первого уровня для автоматизированной настройки Windows.
    Устанавливает необходимое ПО (Git, Python), скачивает Python-загрузчик
    и запускает его для клонирования основного приватного репозитория автоматизации.
.DESCRIPTION
    Этот скрипт выполняет следующие шаги:
    1. Запрашивает у пользователя путь к ВРЕМЕННОМУ РАСШИФРОВАННОМУ приватному SSH-ключу.
    2. Устанавливает Chocolatey (если его нет).
    3. Используя Chocolatey, устанавливает Git и Python 3.
    4. Скачивает Python-скрипт-загрузчик (bootstrap_python.py) из того же публичного репозитория.
    5. Запускает bootstrap_python.py, передавая ему путь к SSH-ключу и URL приватного репозитория.
    6. После завершения работы bootstrap_python.py, удаляет временный SSH-ключ.
.NOTES
    Автор: proga1cma (адаптировано из шаблона)
    Версия: 1.0
    Требуется запуск от имени Администратора.
    Пользователь должен заранее подготовить (расшифровать) свой приватный SSH-ключ.
#>

# --- Начальные настройки и вывод информации ---
Write-Host "--- Загрузчик первого уровня (bootstrap_level1.ps1) ---" -ForegroundColor Yellow
Write-Host "Репозиторий скрипта: https://github.com/proga1cma/my-windows-bootstrap" -ForegroundColor Cyan
Write-Host "Автор: proga1cma" -ForegroundColor Cyan
Write-Host ""

# --- Конфигурация ---
$ErrorActionPreference = "Stop" # Останавливать выполнение при ошибках в командлетах

# URL к Python-загрузчику (в том же репозитории, что и этот скрипт)
$PythonBootstrapScriptUrl = "https://raw.githubusercontent.com/proga1cma/my-windows-bootstrap/main/bootstrap_python.py"
$PythonBootstrapScriptLocalPath = Join-Path -Path $env:TEMP -ChildPath "bootstrap_python.py"

# URL к основному ПРИВАТНОМУ репозиторию автоматизации
$MainAutomationRepoUrl = "git@github.com:proga1cma/YOUR_MAIN_PRIVATE_AUTOMATION_REPO.git" # !!! ЗАМЕНИ НА ИМЯ ТВОЕГО ПРИВАТНОГО РЕПО !!!
$MainAutomationLocalDir = "C:\WindowsAutomationSetup" # Куда будет склонирован основной репозиторий

# Путь, куда будет скопирован предоставленный пользователем SSH-ключ для временного использования
$TempSshKeyForUse = Join-Path -Path $env:TEMP -ChildPath "temp_id_rsa_bootstrap_key"

# --- Функции ---

Function Install-Chocolatey {
    Write-Host "[INFO] Проверка и установка Chocolatey..." -ForegroundColor White
    $ChocoExe = Get-Command choco -ErrorAction SilentlyContinue
    If ($ChocoExe) {
        Write-Host "[SUCCESS] Chocolatey уже установлен: $($ChocoExe.Source)" -ForegroundColor Green
        Return $True
    }
    Try {
        Write-Host "[INFO] Установка Chocolatey..."
        # Команда установки Chocolatey
        Set-ExecutionPolicy Bypass -Scope Process -Force; # Уже должно быть установлено внешней командой, но на всякий случай
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; # Аналогично
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Добавляем choco в PATH для текущей сессии
        $env:Path += ";$($env:ProgramData)\chocolatey\bin"
        Write-Host "[SUCCESS] Chocolatey успешно установлен." -ForegroundColor Green
        Return $True
    } Catch {
        Write-Error "[FAILURE] Ошибка при установке Chocolatey: $($_.Exception.Message)"
        Return $False
    }
}

Function Install-Package-With-Choco {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$PackageName,
        [Parameter(Mandatory=$true)]
        [string]$ChocoId, # Идентификатор пакета для Chocolatey
        [string]$InstallCheckCommand, # Команда для проверки, установлен ли пакет
        [string]$InstallCheckExpectedOutputPattern # Regex-паттерн для ожидаемого вывода
    )
    Write-Host "[INFO] Проверка и установка пакета: $PackageName..." -ForegroundColor White
    $isInstalled = $False
    If ($InstallCheckCommand) {
        Try {
            $checkResult = Invoke-Expression $InstallCheckCommand
            If ($checkResult -match $InstallCheckExpectedOutputPattern) {
                $isInstalled = $True
                Write-Host "[SUCCESS] $PackageName уже установлен." -ForegroundColor Green
            }
        } Catch {
            # Ошибка при проверке, скорее всего, пакет не установлен или команда не найдена
            Write-Host "[INFO] Проверка установки $PackageName не удалась, предполагаем, что пакет не установлен."
        }
    }

    If ($isInstalled) { Return $True }

    Write-Host "[INFO] Установка $PackageName (ID: $ChocoId) через Chocolatey..."
    Try {
        choco install $ChocoId -y --force --no-progress --limit-output
        # Повторная проверка после установки
        If ($InstallCheckCommand) {
            $checkResultAfterInstall = Invoke-Expression $InstallCheckCommand
            If ($checkResultAfterInstall -match $InstallCheckExpectedOutputPattern) {
                Write-Host "[SUCCESS] $PackageName успешно установлен через Chocolatey." -ForegroundColor Green
                Return $True
            } Else {
                Write-Warning "[WARNING] Chocolatey сообщил об установке $PackageName, но проверка ($InstallCheckCommand) не прошла."
                Return $False # Или True, если мы доверяем Choco, но лучше False для строгости
            }
        } Else { # Если команды проверки нет, считаем успешной установку по коду возврата Choco
             Write-Host "[SUCCESS] $PackageName (предположительно) успешно установлен через Chocolatey (нет команды проверки)." -ForegroundColor Green
             Return $True
        }
    } Catch {
        Write-Error "[FAILURE] Ошибка при установке $PackageName через Chocolatey: $($_.Exception.Message)"
        Return $False
    }
}

# --- Основной процесс ---

# Шаг 1: Получение пути к SSH-ключу от пользователя
Write-Host ""
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
Write-Host " ШАГ 1: ПОДГОТОВКА SSH-КЛЮЧА " -ForegroundColor Magenta
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
Write-Host "ВАЖНО: Для доступа к приватному репозиторию GitHub необходим ваш SSH-ключ." -ForegroundColor Yellow
Write-Host "1. Убедитесь, что ваш приватный SSH-ключ (например, id_rsa_github) РАСШИФРОВАН." -ForegroundColor Yellow
Write-Host "2. Скопируйте этот РАСШИФРОВАННЫЙ ключ во временный файл на этой машине." -ForegroundColor Yellow
Write-Host "После завершения настройки этот временный файл ключа будет УДАЛЕН." -ForegroundColor Red
Write-Host ""

$ProvidedSshKeyPathFromUser = ""
While (-not (Test-Path $ProvidedSshKeyPathFromUser -PathType Leaf)) {
    $ProvidedSshKeyPathFromUser = Read-Host -Prompt "Введите ПОЛНЫЙ путь к вашему ВРЕМЕННОМУ РАСШИФРОВАННОМУ приватному SSH-ключу"
    If (-not (Test-Path $ProvidedSshKeyPathFromUser -PathType Leaf)) {
        Write-Warning "[WARNING] Файл не найден по указанному пути. Пожалуйста, проверьте путь и попробуйте снова."
    }
}
Write-Host "[INFO] Используется SSH-ключ, указанный пользователем: $ProvidedSshKeyPathFromUser" -ForegroundColor Cyan

# Копируем предоставленный ключ во временное место, управляемое скриптом
Try {
    Copy-Item -Path $ProvidedSshKeyPathFromUser -Destination $TempSshKeyForUse -Force
    Write-Host "[SUCCESS] Ключ скопирован в '$TempSshKeyForUse' для временного использования." -ForegroundColor Green
} Catch {
    Write-Error "[FAILURE] Не удалось скопировать ключ из '$ProvidedSshKeyPathFromUser' в '$TempSshKeyForUse'. Ошибка: $($_.Exception.Message)"
    Exit 1 # Без ключа дальше нет смысла
}
Write-Host ""

# Шаг 2: Установка Chocolatey
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
Write-Host " ШАГ 2: УСТАНОВКА CHOCOLATEY " -ForegroundColor Magenta
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
If (-not (Install-Chocolatey)) {
    Write-Error "[FAILURE] Не удалось установить Chocolatey. Дальнейшее выполнение невозможно."
    # Попытка удалить временный ключ перед выходом
    If (Test-Path $TempSshKeyForUse) { Remove-Item $TempSshKeyForUse -Force -ErrorAction SilentlyContinue }
    Exit 1
}
Write-Host ""

# Шаг 3: Установка Git
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
Write-Host " ШАГ 3: УСТАНОВКА GIT " -ForegroundColor Magenta
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
If (-not (Install-Package-With-Choco -PackageName "Git" -ChocoId "git.install" -InstallCheckCommand "git --version" -InstallCheckExpectedOutputPattern "git version\s+\d+\.\d+\.\d+")) {
    Write-Error "[FAILURE] Не удалось установить Git. Дальнейшее выполнение невозможно."
    If (Test-Path $TempSshKeyForUse) { Remove-Item $TempSshKeyForUse -Force -ErrorAction SilentlyContinue }
    Exit 1
}
Write-Host ""

# Шаг 4: Установка Python 3
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
Write-Host " ШАГ 4: УСТАНОВКА PYTHON 3 " -ForegroundColor Magenta
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
If (-not (Install-Package-With-Choco -PackageName "Python 3" -ChocoId "python3" -InstallCheckCommand "python --version" -InstallCheckExpectedOutputPattern "Python\s+3\.\d+\.\d+")) {
    # Попытка с python3.exe, если python.exe не найден сразу
    If (-not (Install-Package-With-Choco -PackageName "Python 3" -ChocoId "python3" -InstallCheckCommand "python3 --version" -InstallCheckExpectedOutputPattern "Python\s+3\.\d+\.\d+")) {
        Write-Error "[FAILURE] Не удалось установить Python 3. Дальнейшее выполнение невозможно."
        If (Test-Path $TempSshKeyForUse) { Remove-Item $TempSshKeyForUse -Force -ErrorAction SilentlyContinue }
        Exit 1
    }
}
Write-Host ""

# Шаг 5: Скачивание Python-загрузчика (bootstrap_python.py)
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
Write-Host " ШАГ 5: СКАЧИВАНИЕ PYTHON-ЗАГРУЗЧИКА " -ForegroundColor Magenta
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
Write-Host "[INFO] Скачивание Python-загрузчика ($PythonBootstrapScriptUrl) в '$PythonBootstrapScriptLocalPath'..."
Try {
    # Создаем директорию, если ее нет
    $ParentDir = Split-Path $PythonBootstrapScriptLocalPath -Parent
    If (-not (Test-Path $ParentDir)) {
        New-Item -ItemType Directory -Path $ParentDir -Force | Out-Null
    }
    (New-Object System.Net.WebClient).DownloadFile($PythonBootstrapScriptUrl, $PythonBootstrapScriptLocalPath)
    Write-Host "[SUCCESS] Python-загрузчик успешно скачан." -ForegroundColor Green
} Catch {
    Write-Error "[FAILURE] Ошибка при скачивании Python-загрузчика: $($_.Exception.Message)"
    If (Test-Path $TempSshKeyForUse) { Remove-Item $TempSshKeyForUse -Force -ErrorAction SilentlyContinue }
    Exit 1
}
Write-Host ""

# Шаг 6: Запуск Python-загрузчика (bootstrap_python.py)
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
Write-Host " ШАГ 6: ЗАПУСК PYTHON-ЗАГРУЗЧИКА " -ForegroundColor Magenta
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
Write-Host "[INFO] Запуск Python-загрузчика '$PythonBootstrapScriptLocalPath'..."
$PythonExecutable = "python.exe" # По умолчанию. Можно добавить поиск python3.exe
# Проверим, доступен ли python.exe
If (-not (Get-Command python.exe -ErrorAction SilentlyContinue)) {
    If (Get-Command python3.exe -ErrorAction SilentlyContinue) {
        $PythonExecutable = "python3.exe"
        Write-Host "[INFO] Используется $PythonExecutable"
    } Else {
        Write-Warning "[WARNING] Не удалось найти python.exe или python3.exe. Попытка запустить как 'python'."
    }
}

$PythonScriptExitCode = 1 # По умолчанию - ошибка
Try {
    $Arguments = @(
        "--ssh-key", "`"$TempSshKeyForUse`"", # Передаем путь к временному ключу
        "--repo-url", $MainAutomationRepoUrl,
        "--target-dir", $MainAutomationLocalDir
        # Можно добавить "--req-file", "requirements.txt" если необходимо
    )
    Write-Host "[COMMAND] $PythonExecutable `"$PythonBootstrapScriptLocalPath`" $($Arguments -join ' ')"
    
    # Запускаем Python скрипт. & $PythonExecutable ... не всегда корректно возвращает $LASTEXITCODE
    # Используем Start-Process для лучшего контроля
    $Process = Start-Process -FilePath $PythonExecutable -ArgumentList ($PythonBootstrapScriptLocalPath, $Arguments) -Wait -PassThru -NoNewWindow
    $PythonScriptExitCode = $Process.ExitCode
    
    If ($PythonScriptExitCode -ne 0) {
        Write-Error "[FAILURE] Python-загрузчик завершился с ошибкой (код: $PythonScriptExitCode)."
    } Else {
        Write-Host "[SUCCESS] Python-загрузчик успешно отработал." -ForegroundColor Green
    }
} Catch {
    Write-Error "[FAILURE] Критическая ошибка при запуске Python-загрузчика: $($_.Exception.Message)"
    $PythonScriptExitCode = 255 # Общий код ошибки
} Finally {
    # Шаг 7: Очистка - удаление временного SSH-ключа
    Write-Host ""
    Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
    Write-Host " ШАГ 7: ОЧИСТКА " -ForegroundColor Magenta
    Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
    If (Test-Path $TempSshKeyForUse) {
        Write-Host "[INFO] Удаление временного SSH-ключа: '$TempSshKeyForUse'" -ForegroundColor Yellow
        Try {
            Remove-Item $TempSshKeyForUse -Force -ErrorAction Stop
            If (-not (Test-Path $TempSshKeyForUse)) {
                Write-Host "[SUCCESS] Временный SSH-ключ успешно удален." -ForegroundColor Green
            } Else {
                # Это не должно произойти, если ErrorAction Stop сработал, но на всякий случай
                Write-Warning "[WARNING] Не удалось подтвердить удаление временного SSH-ключа: '$TempSshKeyForUse'. Пожалуйста, удалите его вручную!"
            }
        } Catch {
             Write-Warning "[WARNING] Ошибка при удалении временного SSH-ключа '$TempSshKeyForUse': $($_.Exception.Message). Пожалуйста, удалите его вручную!"
        }
    } Else {
        Write-Host "[INFO] Временный SSH-ключ '$TempSshKeyForUse' не найден для удаления (возможно, уже удален или не был создан)."
    }
}

Write-Host ""
If ($PythonScriptExitCode -ne 0) {
    Write-Error "[FAILURE] Загрузка и настройка завершились с ошибками."
    Exit $PythonScriptExitCode
}

Write-Host "--- Загрузчик первого уровня (bootstrap_level1.ps1) успешно завершил работу. ---" -ForegroundColor Yellow
Write-Host "Основной проект автоматизации должен быть склонирован в: $MainAutomationLocalDir" -ForegroundColor Cyan
Write-Host "Для продолжения настройки:" -ForegroundColor Cyan
Write-Host "1. Перейдите в директорию: cd '$MainAutomationLocalDir'" -ForegroundColor Cyan
Write-Host "2. Запустите главный скрипт автоматизации (например, main_runner.py) от имени Администратора." -ForegroundColor Cyan
Write-Host "   Пример: python main_runner.py" -ForegroundColor Cyan
Write-Host ""
Exit 0 # Успешное завершение