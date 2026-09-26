@echo off
echo =========================================
echo    Starting OptiFlow Development Environment
echo =========================================

echo.
echo Starting Backend (FastAPI / Uvicorn)...
start "OptiFlow Backend" cmd /k "cd optiflow_back && uvicorn main:app --reload --port 8000"

echo.
echo Starting Frontend (Flutter Windows)...
start "OptiFlow Frontend" cmd /k "cd optiflow_front && flutter run -d windows"

echo.
echo Starting Frontend (Flutter Android)...
start "OptiFlow Frontend" cmd /k "cd optiflow_front && flutter run"


echo.
echo Both services have been launched in separate terminal windows!
echo Close this window at any time.
