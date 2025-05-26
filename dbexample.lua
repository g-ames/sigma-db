local SigmaDB = {}

local HttpService = game:GetService("HttpService")

local SIGMA_DB_URL = "YOUR_NGROK_HTTPS_URL_HERE/sql"

function SigmaDB.sendSQLRequest(query, params)
    if not query or type(query) ~= "string" then
        warn("sendSQLRequest: Invalid query provided.")
        return nil, "Invalid query"
    end

    local requestBody = { query = query }
    if params and type(params) == "table" then
        requestBody.params = params
    end

    local jsonBody = HttpService:JSONEncode(requestBody)

    local success, responseTable = pcall(function()
        return HttpService:RequestAsync({
            Url = SIGMA_DB_URL,
            Method = "POST",
            Headers = { ["Content-Type"] = "application/json" },
            Body = jsonBody,
        })
    end)

    if success then
        if responseTable.Success then
            local decodedResponse = HttpService:JSONDecode(responseTable.Body)
            if decodedResponse and decodedResponse.success then
                return decodedResponse.data, nil
            else
                warn("Sigma-DB returned an error:", decodedResponse.error or "Unknown error")
                return nil, decodedResponse.error or "Sigma-DB returned an error"
            end
        else
            warn("HTTP Request failed (Roblox error):", responseTable.StatusCode, responseTable.StatusMessage)
            return nil, responseTable.StatusMessage or "Unknown HTTP error"
        end
    else
        warn("HTTP Request failed:", responseTable)
        return nil, responseTable
    end
end

function initializeDatabase()
    local schemaSQL = [[
        CREATE TABLE IF NOT EXISTS Servers (
            ServerId INTEGER PRIMARY KEY,
            ServerName TEXT NOT NULL,
            IPAddress TEXT
        );

        CREATE TABLE IF NOT EXISTS Players (
            PlayerId INTEGER PRIMARY KEY,
            Username TEXT NOT NULL,
            Email TEXT,
            DateJoined DATETIME DEFAULT CURRENT_TIMESTAMP
        );

        CREATE TABLE IF NOT EXISTS PlayerStats (
            PlayerId INTEGER PRIMARY KEY,
            Health INTEGER DEFAULT 100,
            Stamina INTEGER DEFAULT 100,
            Hunger INTEGER DEFAULT 100,
            Oxygen INTEGER DEFAULT 100,
            Temperature INTEGER DEFAULT 100,
            FOREIGN KEY (PlayerId) REFERENCES Players(PlayerId)
        );

        CREATE TABLE IF NOT EXISTS PlayerPositions (
            PlayerId INTEGER,
            ServerId INTEGER,
            X FLOAT,
            Y FLOAT,
            Z FLOAT,
            PRIMARY KEY (PlayerId, ServerId),
            FOREIGN KEY (PlayerId) REFERENCES Players(PlayerId),
            FOREIGN KEY (ServerId) REFERENCES Servers(ServerId)
        );

        CREATE TABLE IF NOT EXISTS Structures (
            StructureId INTEGER PRIMARY KEY,
            OwnerId INTEGER,
            Name TEXT,
            X FLOAT,
            Y FLOAT,
            Z FLOAT,
            Type TEXT,
            ServerId INTEGER,
            FOREIGN KEY (OwnerId) REFERENCES Players(PlayerId),
            FOREIGN KEY (ServerId) REFERENCES Servers(ServerId)
        );

        CREATE TABLE IF NOT EXISTS PlayerServerSaves (
            PlayerId INTEGER,
            ServerId INTEGER,
            SaveData JSON,
            PRIMARY KEY (PlayerId, ServerId),
            FOREIGN KEY (PlayerId) REFERENCES Players(PlayerId),
            FOREIGN KEY (ServerId) REFERENCES Servers(ServerId)
        );
    ]]

    local data, err = sendSQLRequest(schemaSQL)
    if data then
        print("Database schema initialized successfully!")
    else
        warn("Failed to initialize the database schema:", err)
    end
end

function SigmaDB.createPlayer(userId, username)
    local query = "INSERT INTO Players (PlayerId, Username) VALUES (?, ?)"
    local params = {userId, username}
    local data, err = sendSQLRequest(query, params)
    if data then
        print("Player created successfully!")
    else
        warn("Failed to create player:", err)
    end
end

function SigmaDB.upsertPlayerStats(userId, health, stamina, hunger, oxygen, temperature)
    local query = "INSERT INTO PlayerStats (PlayerId, Health, Stamina, Hunger, Oxygen, Temperature) VALUES (?, ?, ?, ?, ?, ?) " ..
                  "ON CONFLICT(PlayerId) DO UPDATE SET Health = ?, Stamina = ?, Hunger = ?, Oxygen = ?, Temperature = ?"
    local params = {userId, health, stamina, hunger, oxygen, temperature, health, stamina, hunger, oxygen, temperature}
    local data, err = sendSQLRequest(query, params)
    if data then
        print("Player stats updated!")
    else
        warn("Failed to update stats:", err)
    end
end

function SigmaDB.savePlayerPosition(userId, serverId, x, y, z)
    local query = "INSERT INTO PlayerPositions (PlayerId, ServerId, X, Y, Z) VALUES (?, ?, ?, ?, ?) " ..
                  "ON CONFLICT(PlayerId, ServerId) DO UPDATE SET X = ?, Y = ?, Z = ?"
    local params = {userId, serverId, x, y, z, x, y, z}
    local data, err = sendSQLRequest(query, params)
    if data then
        print("Player position saved!")
    else
        warn("Failed to save position:", err)
    end
end

function SigmaDB.saveStructure(ownerId, structureId, name, x, y, z, structureType, serverId)
    local query = "INSERT INTO Structures (StructureId, OwnerId, Name, X, Y, Z, Type, ServerId) VALUES (?, ?, ?, ?, ?, ?, ?, ?)"
    local params = {structureId, ownerId, name, x, y, z, structureType, serverId}
    local data, err = sendSQLRequest(query, params)
    if data then
        print("Structure saved!")
    else
        warn("Failed to save structure:", err)
    end
end

function SigmaDB.savePlayerServerData(userId, serverId, saveData)
    local query = "INSERT INTO PlayerServerSaves (PlayerId, ServerId, SaveData) VALUES (?, ?, ?) " ..
                  "ON CONFLICT(PlayerId, ServerId) DO UPDATE SET SaveData = ?"
    local params = {userId, serverId, HttpService:JSONEncode(saveData), HttpService:JSONEncode(saveData)}
    local data, err = sendSQLRequest(query, params)
    if data then
        print("Player save data updated for server:", serverId)
    else
        warn("Failed to update save data:", err)
    end
end

initializeDatabase()

return SigmaDB