-- SigmaDBConnector (Server Script)

local HttpService = game:GetService("HttpService")

-- IMPORTANT: Replace this with your actual ngrok HTTPS URL or your deployed server's HTTPS URL
-- This URL MUST be HTTPS.
local SIGMA_DB_URL = "YOUR_NGROK_HTTPS_URL_HERE/sql" -- e.g., "https://abcdef123.ngrok-free.app/sql"

-- Function to send a raw SQL query to Sigma-DB
-- query: string (the SQL statement)
-- params: table (optional, an array of parameters for prepared statements)
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
    
    print("Attempting to send SQL query to Sigma-DB...")
    print("Query: " .. query)
    if params then
        print("Params: " .. HttpService:JSONEncode(params))
    end
    print("URL: " .. SIGMA_DB_URL)

    local success, responseTable = pcall(function()
        return HttpService:RequestAsync({
            Url = SIGMA_DB_URL,
            Method = "POST",
            Headers = {
                -- This is where you correctly set Content-Type for RequestAsync!
                ["Content-Type"] = "application/json",
            },
            Body = jsonBody,
        })
    end)

    if success then
        if responseTable.Success then
            print("SQL Request successful!")
            print("Raw Response Body: " .. responseTable.Body)
            local decodedResponse = HttpService:JSONDecode(responseTable.Body)
            if decodedResponse and decodedResponse.success then
                return decodedResponse.data, nil
            else
                warn("Sigma-DB returned an error or unsuccessful response:", decodedResponse.error or "Unknown error")
                return nil, decodedResponse.error or "Sigma-DB returned an error"
            end
        else
            warn("HTTP Request failed (Roblox error):", responseTable.StatusCode, responseTable.StatusMessage)
            warn("Response Body:", responseTable.Body) -- May contain useful error from Sigma-DB
            return nil, responseTable.StatusMessage or "Unknown HTTP error"
        end
    else
        warn("HTTP Request failed (pcall error):", responseTable) -- 'responseTable' here is the error message from pcall
        return nil, responseTable
    end
end

-- --- TEST USAGE ---

-- Test 1: Create a table (if it doesn't exist)
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
    task.wait(1) -- Small delay between requests
end

-- Test 2: Insert data
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
        -- Check for specific error message from Sigma-DB about unique constraint
        if type(err) == "string" and string.find(err, "UNIQUE constraint failed") then
            print("User ID or Username already exists. Trying to update instead.")
            -- If insert fails due to unique constraint, try updating
            testUpdateData(userId, username, kills, deaths)
        end
    end
    task.wait(1)
end

-- Test 3: Select data
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

-- Test 4: Update data
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


-- Call the test functions in order
task.wait(5) -- Give Sigma-DB a moment to start up if running locally
testCreateTable()
testInsertData(1001, "PlayerOne", 10, 5)
testInsertData(1002, "PlayerTwo", 25, 8)
testInsertData(1003, "PlayerThree", 12, 15)
testInsertData(1001, "PlayerOneUpdated", 15, 7) -- Should trigger an update due to unique constraint or just update if it exists
testSelectData(1002)
testSelectData(9999) -- Non-existent user
testSelectData(nil) -- Select all