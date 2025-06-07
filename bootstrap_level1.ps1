# bootstrap_level1.ps1
# ВАЖНО: Сохраните этот файл в кодировке UTF-8 with BOM!
#
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
    Версия: 1.1 (с улучшенной поддержкой кириллицы)
    Требуется запуск от имени Администратора.
    Пользователь должен заранее подготовить (расшифровать) свой приватный SSH-ключ.
#>

# --- Начальные настройки и вывод информации ---
$ProgressPreference = 'SilentlyContinue' # Отключаем прогресс-бары для более чистого вывода
$ErrorActionPreference = "Stop" # Останавливать выполнение при ошибках в командлетах, которые это поддерживают

# Попытка установить кодировку вывода консоли в UTF-8 для лучшего отображения кириллицы
# Это может не сработать или не дать эффекта, если шрифт консоли не поддерживает Unicode.
# Начиная с Windows 10 версии 1903, можно изменить активную кодовую страницу на UTF-8 (chcp 65001),
# но это лучше делать до запуска PowerShell.
# Для текущего сеанса PowerShell можно установить $OutputEncoding.
try {
    $OutputEncoding = [System.Text.Encoding]::UTF8
    # Если используется PowerShell Core (pwsh.exe), эта строка не всегда нужна, т.к. он лучше работает с UTF-8.
} catch {
    Write-Warning "Не удалось установить кодировку вывода в UTF-8. Кириллица может отображаться некорректно."
}

Write-Host "--- Загрузчик первого уровня (bootstrap_level1.ps1) ---" -ForegroundColor Yellow
Write-Host "Репозиторий скрипта: https://github.com/proga1cma/my-windows-bootstrap" -ForegroundColor Cyan
Write-Host "Автор: proga1cma" -ForegroundColor Cyan
Write-Host "Версия: 1.1" -ForegroundColor Cyan
Write-Host ""

# --- Конфигурация ---
# URL к Python-загрузчику (в том же репозитории, что и этот скрипт)
$PythonBootstrapScriptUrl = "https://raw.githubusercontent.com/proga1cma/my-windows-bootstrap/main/bootstrap_python.py"
$PythonBootstrapScriptLocalPath = Join-Path -Path $env:TEMP -ChildPath "bootstrap_python.py"

# URL к основному ПРИВАТНОМУ репозиторию автоматизации
$MainAutomationRepoUrl = "git@github.com:proga1cma/YOUR_MAIN_PRIVATE_AUTOMATION_REPO.git" # !!! ЗАМЕНИ НА ИМЯ ТВОЕГО ПРИВАТНОГО РЕПО !!!
$MainAutomationLocalDir = "C:\WindowsAutomationSetup" # Куда будет склонирован основной репозиторий

# Путь, куда будет скопирован предоставленный пользователем SSH-ключ для временного использования
$TempSshKeyForUse = Join-Path -Path $env:TEMP -ChildPath "temp_id_rsa_bootstrap_key_$(Get-Random)" # Добавляем случайное число для уникальности

# --- Функции ---

Function Install-Chocolatey {
    Write-Host "[ИНФО] Проверка и установка Chocolatey..." -ForegroundColor White
    $ChocoExe = Get-Command choco -ErrorAction SilentlyContinue
    If ($ChocoExe) {
        Write-Host "[УСПЕХ] Chocolatey уже установлен: $($ChocoExe.Source)" -ForegroundColor Green
        Return $True
    }
    Try {
        Write-Host "[ИНФО] Установка Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force;
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072;
        iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        $env:Path += ";$($env:ProgramData)\chocolatey\bin"
        Write-Host "[УСПЕХ] Chocolatey успешно установлен." -ForegroundColor Green
        Return $True
    } Catch {
        Write-Error "[ОШИБКА] Ошибка при установке Chocolatey: $($_.Exception.Message)"
        Write-Error "Полная информация об ошибке: $_"
        Return $False
    }
}

Function Install-Package-With-Choco {
    Param(
        [Parameter(Mandatory=$true)]
        [string]$PackageName, # Имя пакета для отображения пользователю
        [Parameter(Mandatory=$true)]
        [string]$ChocoId,
        [string]$InstallCheckCommand,
        [string]$InstallCheckExpectedOutputPattern
    )
    Write-Host "[ИНФО] Проверка и установка пакета: $PackageName..." -ForegroundColor White
    $isInstalled = $False
    If ($InstallCheckCommand) {
        Try {
            $checkResult = Invoke-Expression $InstallCheckCommand
            If ($checkResult -match $InstallCheckExpectedOutputPattern) {
                $isInstalled = $True
                Write-Host "[УСПЕХ] $PackageName уже установлен." -ForegroundColor Green
            }
        } Catch {
            Write-Host "[ИНФО] Проверка установки $PackageName не удалась, предполагаем, что пакет не установлен."
        }
    }

    If ($isInstalled) { Return $True }

    Write-Host "[ИНФО] Установка $PackageName (ID: $ChocoId) через Chocolatey..."
    Try {
        choco install $ChocoId -y --force --no-progress --limit-output
        If ($InstallCheckCommand) {
            $checkResultAfterInstall = Invoke-Expression $InstallCheckCommand
            If ($checkResultAfterInstall -match $InstallCheckExpectedOutputPattern) {
                Write-Host "[УСПЕХ] $PackageName успешно установлен через Chocolatey." -ForegroundColor Green
                Return $True
            } Else {
                Write-Warning "[ПРЕДУПРЕЖДЕНИЕ] Chocolatey сообщил об установке $PackageName, но проверка ($InstallCheckCommand) не прошла."
                Return $False
            }
        } Else {
             Write-Host "[УСПЕХ] $PackageName (предположительно) успешно установлен через Chocolatey (нет команды проверки)." -ForegroundColor Green
             Return $True
        }
    } Catch {
        Write-Error "[ОШИБКА] Ошибка при установке $PackageName через Chocolatey: $($_.Exception.Message)"
        Write-Error "Полная информация об ошибке: $_"
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
    $PromptMessage = "Введите ПОЛНЫЙ путь к вашему ВРЕМЕННОМУ РАСШИФРОВАННОМУ приватному SSH-ключу"
    $ProvidedSshKeyPathFromUser = Read-Host -Prompt $PromptMessage
    If (-not (Test-Path $ProvidedSshKeyPathFromUser -PathType Leaf)) {
        Write-Warning "[ПРЕДУПРЕЖДЕНИЕ] Файл не найден по указанному пути. Пожалуйста, проверьте путь и попробуйте снова."
    }
}
Write-Host "[ИНФО] Используется SSH-ключ, указанный пользователем: $ProvidedSshKeyPathFromUser" -ForegroundColor Cyan

Try {
    Copy-Item -Path $ProvidedSshKeyPathFromUser -Destination $TempSshKeyForUse -Force
    Write-Host "[УСПЕХ] Ключ скопирован в '$TempSshKeyForUse' для временного использования." -ForegroundColor Green
} Catch {
    Write-Error "[ОШИБКА] Не удалось скопировать ключ из '$ProvidedSshKeyPathFromUser' в '$TempSshKeyForUse'. Ошибка: $($_.Exception.Message)"
    Write-Error "Полная информация об ошибке: $_"
    Exit 1
}
Write-Host ""

# Шаг 2: Установка Chocolatey
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
Write-Host " ШАГ 2: УСТАНОВКА CHOCOLATEY " -ForegroundColor Magenta
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
If (-not (Install-Chocolatey)) {
    Write-Error "[ОШИБКА] Не удалось установить Chocolatey. Дальнейшее выполнение невозможно."
    If (Test-Path $TempSshKeyForUse) { Remove-Item $TempSshKeyForUse -Force -ErrorAction SilentlyContinue }
    Exit 1
}
Write-Host ""

# Шаг 3: Установка Git
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
Write-Host " ШАГ 3: УСТАНОВКА GIT " -ForegroundColor Magenta
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
If (-not (Install-Package-With-Choco -PackageName "Git" -ChocoId "git.install" -InstallCheckCommand "git --version" -InstallCheckExpectedOutputPattern "git version\s+\d+\.\d+\.\d+")) {
    Write-Error "[ОШИБКА] Не удалось установить Git. Дальнейшее выполнение невозможно."
    If (Test-Path $TempSshKeyForUse) { Remove-Item $TempSshKeyForUse -Force -ErrorAction SilentlyContinue }
    Exit 1
}
Write-Host ""

# Шаг 4: Установка Python 3
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
Write-Host " ШАГ 4: УСТАНОВКА PYTHON 3 " -ForegroundColor Magenta
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
If (-not (Install-Package-With-Choco -PackageName "Python 3" -ChocoId "python3" -InstallCheckCommand "python --version" -InstallCheckExpectedOutputPattern "Python\s+3\.\d+\.\d+")) {
    If (-not (Install-Package-With-Choco -PackageName "Python 3" -ChocoId "python3" -InstallCheckCommand "python3 --version" -InstallCheckExpectedOutputPattern "Python\s+3\.\d+\.\d+")) {
        Write-Error "[ОШИБКА] Не удалось установить Python 3. Дальнейшее выполнение невозможно."
        If (Test-Path $TempSshKeyForUse) { Remove-Item $TempSshKeyForUse -Force -ErrorAction SilentlyContinue }
        Exit 1
    }
}
Write-Host ""

# Шаг 5: Скачивание Python-загрузчика (bootstrap_python.py)
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
Write-Host " ШАГ 5: СКАЧИВАНИЕ PYTHON-ЗАГРУЗЧИКА " -ForegroundColor Magenta
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
Write-Host "[ИНФО] Скачивание Python-загрузчика ($PythonBootstrapScriptUrl) в '$PythonBootstrapScriptLocalPath'..."
Try {
    $ParentDir = Split-Path $PythonBootstrapScriptLocalPath -Parent
    If (-not (Test-Path $ParentDir)) { New-Item -ItemType Directory -Path $ParentDir -Force | Out-Null }
    (New-Object System.Net.WebClient).DownloadFile($PythonBootstrapScriptUrl, $PythonBootstrapScriptLocalPath)
    Write-Host "[УСПЕХ] Python-загрузчик успешно скачан." -ForegroundColor Green
} Catch {
    Write-Error "[ОШИБКА] Ошибка при скачивании Python-загрузчика: $($_.Exception.Message)"
    Write-Error "Полная информация об ошибке: $_"
    If (Test-Path $TempSshKeyForUse) { Remove-Item $TempSshKeyForUse -Force -ErrorAction SilentlyContinue }
    Exit 1
}
Write-Host ""

# Шаг 6: Запуск Python-загрузчика (bootstrap_python.py)
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
Write-Host " ШАГ 6: ЗАПУСК PYTHON-ЗАГРУЗЧИКА " -ForegroundColor Magenta
Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
Write-Host "[ИНФО] Запуск Python-загрузчика '$PythonBootstrapScriptLocalPath'..."
$PythonExecutable = "python.exe"
If (-not (Get-Command python.exe -ErrorAction SilentlyContinue)) {
    If (Get-Command python3.exe -ErrorAction SilentlyContinue) { $PythonExecutable = "python3.exe"; Write-Host "[ИНФО] Используется $PythonExecutable" }
    Else { Write-Warning "[ПРЕДУПРЕЖДЕНИЕ] Не удалось найти python.exe или python3.exe. Попытка запустить как 'python'." }
}

$PythonScriptExitCode = 1
Try {
    $Arguments = @(
        "`"$PythonBootstrapScriptLocalPath`"", # Путь к Python скрипту первым
        "--ssh-key", "`"$TempSshKeyForUse`"",
        "--repo-url", $MainAutomationRepoUrl,
        "--target-dir", $MainAutomationLocalDir
    )
    Write-Host "[КОМАНДА] & `"$PythonExecutable`" $($Arguments -join ' ')"
    
    # Использование Invoke-Expression для запуска, чтобы перенаправить вывод в консоль PowerShell
    # Важно: Аргументы должны быть правильно экранированы.
    $CommandToRun = "& `"$PythonExecutable`" " + ($Arguments | ForEach-Object { "`"$_`"" } | Join-String -Separator " ")
    # Write-Host "[DEBUG] Команда для Invoke-Expression: $CommandToRun" # Для отладки
    Invoke-Expression $CommandToRun
    $PythonScriptExitCode = $LASTEXITCODE # Получаем код возврата от Python скрипта
    
    If ($PythonScriptExitCode -ne 0) {
        Write-Error "[ОШИБКА] Python-загрузчик завершился с ошибкой (код: $PythonScriptExitCode)."
    } Else {
        Write-Host "[УСПЕХ] Python-загрузчик успешно отработал." -ForegroundColor Green
    }
} Catch {
    Write-Error "[ОШИБКА] Критическая ошибка при запуске Python-загрузчика: $($_.Exception.Message)"
    Write-Error "Полная информация об ошибке: $_"
    $PythonScriptExitCode = 255
} Finally {
    # Шаг 7: Очистка - удаление временного SSH-ключа
    Write-Host ""
    Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
    Write-Host " ШАГ 7: ОЧИСТКА " -ForegroundColor Magenta
    Write-Host "----------------------------------------------------------------------" -ForegroundColor Magenta
    If (Test-Path $TempSshKeyForUse) {
        Write-Host "[ИНФО] Удаление временного SSH-ключа: '$TempSshKeyForUse'" -ForegroundColor Yellow
        Try {
            Remove-Item $TempSshKeyForUse -Force -ErrorAction Stop
            If (-not (Test-Path $TempSshKeyForUse)) {
                Write-Host "[УСПЕХ] Временный SSH-ключ успешно удален." -ForegroundColor Green
            } Else {
                Write-Warning "[ПРЕДУПРЕЖДЕНИЕ] Не удалось подтвердить удаление временного SSH-ключа: '$TempSshKeyForUse'. Пожалуйста, удалите его вручную!"
            }
        } Catch {
             Write-Warning "[ПРЕДУПРЕЖДЕНИЕ] Ошибка при удалении временного SSH-ключа '$TempSshKeyForUse': $($_.Exception.Message). Пожалуйста, удалите его вручную!"
             Write-Warning "Полная информация об ошибке: $_"
        }
    } Else {
        Write-Host "[ИНФО] Временный SSH-ключ '$TempSshKeyForUse' не найден для удаления."
    }
}

Write-Host ""
If ($PythonScriptExitCode -ne 0) {
    Write-Error "[ЗАВЕРШЕНИЕ С ОШИБКАМИ] Загрузка и настройка не были полностью успешными."
    Exit $PythonScriptExitCode
}

Write-Host "--- Загрузчик первого уровня (bootstrap_level1.ps1) успешно завершил работу. ---" -ForegroundColor Yellow
Write-Host "Основной проект автоматизации должен быть склонирован в: '$MainAutomationLocalDir'" -ForegroundColor Cyan
Write-Host "Для продолжения настройки:" -ForegroundColor Cyan
Write-Host "1. Перейдите в директорию: cd '$MainAutomationLocalDir'" -ForegroundColor Cyan
Write-Host "2. Запустите главный скрипт автоматизации (например, main_runner.py) от имени Администратора." -ForegroundColor Cyan
Write-Host "   Пример: python main_runner.py" -ForegroundColor Cyan
Write-Host ""
Exit 0
