-- THe file contain the functions for Mod logiing

function ToLog(str) -- Функция для записи в лог действий скрипта
	if str == nil then str = 'nil'; end;
	local DateTime=os.sysdate(); -- Текущие дата/время
   -- Записывает в лог-файл переданную строку, добавляя в ее начало время 
   Log:write(string.format("%02d", DateTime.day).."-"
            ..string.format("%02d", DateTime.month).."-"
            ..string.format("%04d", DateTime.year).." "
            ..string.format("%02d", DateTime.hour)..":"
            ..string.format("%02d", DateTime.min)..":"
            ..string.format("%02d", DateTime.sec).."."
			..string.format("%06d", DateTime.mcs).."  "
            ..str.."\n");  -- Записывает в лог-файл
   Log:flush();   -- Сохраняет изменения в лог-файле
end;
function OpenLogFile(str) -- Функция для открытия Log файла
	-- Пытается открыть лог-файл в режиме "чтения/записи"
	if str==nil then str='log'; end;
	local DateTime=os.date("*t",os.time());
	local LogFileName='\\'..string.format("%04d", DateTime.year)..'-'..
                           string.format("%02d", DateTime.month)..'-'..
					       string.format("%02d", DateTime.day)..'-'..
					       str..'.log';
	Log = io.open(getScriptPath()..LogFileName,"r+");
	-- Если файл не существует
	if Log == nil then 
		-- Создает файл в режиме "записи"
		Log = io.open(getScriptPath()..LogFileName,"w"); 
		-- Закрывает файл
		Log:close();
		-- Открывает уже существующий файл в режиме "чтения/записи"
		Log = io.open(getScriptPath()..LogFileName,"r+");
	end; 
	-- Проверка
	if Log == nil then
		return false;
	end;
	-- Встает в конец файла
	Log:seek("end",0);
	-- Добавляет пустую строку-разрыв
	Log:write("\n");
	ToLog('OpenLogFile. Logging has started'); -- Пишем в лог-файл следующее  
	Log:flush();
	return true;
end;
function CloseLogFile(str) -- Функция для закрытия Log файла
	if str == nil then str = "Log file has been closed"; end;
	if Log ~= nil then --При выходе из программы закрываем Log файл
		ToLog("CloseLogFile. "..str.."\n");  -- Записывает в лог-файл
		Log:close();
	end; 
end;
