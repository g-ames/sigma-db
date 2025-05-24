local HttpService = game:GetService("HttpService")

local SIGMA_DB_URL = "https://ba3c-184-17-92-81.ngrok-free.app/sql" 

local function sendSQLRequest(query, params)
    if not query or type(query) ~= "string" then
        warn("sendSQLRequest: Invalid query provided.")
        return nil, "Invalid query"
    end

    local requestBody = {
        query = query
    }
    if params and type(params) == "table" then
        requestBody.params = params
    end

    local jsonBody = HttpService:JSONEncode(requestBody)
    local headers = {
        ["Content-Type"] = "application/json"
    }

    print("Attempting to send SQL query to Sigma-DB...")
    print("Query: " .. query)
    if params then
        print("Params: " .. HttpService:JSONEncode(params))
    end
    print("URL: " .. SIGMA_DB_URL)

    local success, response = pcall(function()
        return HttpService:PostAsync(SIGMA_DB_URL, jsonBody, Enum.HttpContentType.ApplicationJson, false, headers)
    end)

    if success then
        print("SQL Request successful!")
        print("Raw Response: " .. response)
        local decodedResponse = HttpService:JSONDecode(response)
        if decodedResponse and decodedResponse.success then
            return decodedResponse.data, nil
        else
            warn("Sigma-DB returned an error or unsuccessful response:", decodedResponse.error or "Unknown error")
            return nil, decodedResponse.error or "Sigma-DB returned an error"
        end
    else
        warn("HTTP Request failed:", response)
        return nil, response
    end
end

local function testCreateTable()
    print("\n--- Testing CREATE TABLE ---")
    local createQuery = "CREATE TABLE IF NOT EXISTS PlayersData (UserId INTEGER PRIMARY KEY, Username TEXT, Kills INTEGER, Deaths INTEGER)"
    local data, err = sendSQLRequest(createQuery)
    if data then
        print("Table 'PlayersData' creation successful!")
        print(HttpService:JSONEncode(data))
    else
        warn("Failed to create table:", err)
    end
    task.wait(1) 
end

local function testInsertData(userId, username, kills, deaths)
    print("\n--- Testing INSERT DATA ---")
    local insertQuery = "INSERT INTO PlayersData (UserId, Username, Kills, Deaths) VALUES (?, ?, ?, ?)"
    local insertParams = {userId, username, kills, deaths}
    local data, err = sendSQLRequest(insertQuery, insertParams)
    if data then
        print(string.format("Inserted data for %s (ID: %d): Kills=%d, Deaths=%d", username, userId, kills, deaths))
        print(HttpService:JSONEncode(data))
    else
        warn(string.format("Failed to insert data for %s:", username), err)
        if string.find(err or "", "UNIQUE constraint failed") then
            print("User ID or Username already exists. Trying to update instead.")

            testUpdateData(userId, username, kills, deaths)
        end
    end
    task.wait(1)
end

local function testSelectData(userId)
    print("\n--- Testing SELECT DATA ---")
    local selectQuery
    local selectParams
    if userId then
        selectQuery = "SELECT * FROM PlayersData WHERE UserId = ?"
        selectParams = {userId}
        print(string.format("Selecting data for UserId %d...", userId))
    else
        selectQuery = "SELECT * FROM PlayersData"
        print("Selecting all data...")
    end

    local data, err = sendSQLRequest(selectQuery, selectParams)
    if data then
        print("Select successful! Retrieved data:")
        if #data > 0 then
            for i, row in ipairs(data) do
                print(string.format("  User: %s (ID: %d), Kills: %d, Deaths: %d", row.Username, row.UserId, row.Kills, row.Deaths))
            end
        else
            print("  No data found.")
        end
    else
        warn("Failed to select data:", err)
    end
    task.wait(1)
end

local function testUpdateData(userId, username, kills, deaths)
    print("\n--- Testing UPDATE DATA ---")
    local updateQuery = "UPDATE PlayersData SET Username = ?, Kills = ?, Deaths = ? WHERE UserId = ?"
    local updateParams = {username, kills, deaths, userId}
    local data, err = sendSQLRequest(updateQuery, updateParams)
    if data then
        print(string.format("Updated data for %s (ID: %d): Kills=%d, Deaths=%d", username, userId, kills, deaths))
        print(HttpService:JSONEncode(data))
    else
        warn(string.format("Failed to update data for %s:", username), err)
    end
    task.wait(1)
end

task.wait(5) 
testCreateTable()
testInsertData(1001, "PlayerOne", 10, 5)
testInsertData(1002, "PlayerTwo", 25, 8)
testInsertData(1003, "PlayerThree", 12, 15)
testInsertData(1001, "PlayerOneUpdated", 15, 7) 
testSelectData(1002)
testSelectData(9999) 
testSelectData(nil) 