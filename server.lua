ESX = exports["es_extended"]:getSharedObject()

ESX.RegisterServerCallback('high_bank:requestinfo', function(source, cb)
    local xPlayer = ESX.GetPlayerFromId(source)
    if xPlayer then
        local playerIdentifier = xPlayer.identifier
        
        local query = "SELECT iban FROM high_bank WHERE identifier = @identifier"
        MySQL.Async.fetchScalar(query, {
            ['@identifier'] = playerIdentifier
        }, function(iban)
            local bankMoney = xPlayer.getAccount('bank').money
            if iban then
                cb(bankMoney, iban)
            else
                cb(bankMoney, "Non Trovato")
            end
        end)
    end
end)


RegisterNetEvent('high_bank:deposita')
AddEventHandler('high_bank:deposita', function(depositare)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local contantiMoney = xPlayer.getAccount('money').money
    local bankMoney = xPlayer.getAccount('bank').money

    depositare = tonumber(depositare)

    if depositare and depositare > 0 then
        if contantiMoney >= depositare then
            xPlayer.addAccountMoney('bank', depositare)
            xPlayer.removeAccountMoney('money', depositare)
            xPlayer.showNotification('Hai depositato: ' .. depositare .. '€')
        else
            xPlayer.showNotification('Non hai abbastanza soldi contanti.')
        end
    else
        xPlayer.showNotification('Importo non valido per il deposito.')
    end
end)

RegisterNetEvent('high_bank:preleva')
AddEventHandler('high_bank:preleva', function(prelevare)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local contantiMoney = xPlayer.getAccount('money').money
    local bankMoney = xPlayer.getAccount('bank').money

    prelevare = tonumber(prelevare)

    if prelevare and prelevare > 0 then
        if bankMoney >= prelevare then
            xPlayer.addAccountMoney('money', prelevare)
            xPlayer.removeAccountMoney('bank', prelevare)
            xPlayer.showNotification('Hai prelevato: ' .. prelevare .. '€')
        else
            xPlayer.showNotification('Non hai abbastanza soldi in banca.')
        end
    else
        xPlayer.showNotification('Importo non valido per il prelievo.')
    end
end)

RegisterNetEvent('high_bank:trasferisci')
AddEventHandler('high_bank:trasferisci', function (ibanacuitrasferire, importodatrasferire)
    local xPlayer = ESX.GetPlayerFromId(source)
    if not xPlayer then return end

    local query = "SELECT identifier FROM high_bank WHERE iban = @iban"
    MySQL.Async.fetchScalar(query, {
        ['@iban'] = ibanacuitrasferire
    }, function(targetIdentifier)
        if targetIdentifier then
            local xRicevitoreSoldi = ESX.GetPlayerFromIdentifier(targetIdentifier)
            if not xRicevitoreSoldi then
                xPlayer.showNotification('Giocatore non trovato.')
                return
            end

            local bankMoney = xPlayer.getAccount('bank').money
            importodatrasferire = tonumber(importodatrasferire)

            if importodatrasferire and importodatrasferire > 0 then
                if bankMoney >= importodatrasferire then
                    xRicevitoreSoldi.addAccountMoney('bank', importodatrasferire)
                    xPlayer.removeAccountMoney('bank', importodatrasferire)
                    xPlayer.showNotification('Hai trasferito: ' .. importodatrasferire .. '€' ..' al player ' .. xRicevitoreSoldi.getName())
                    xRicevitoreSoldi.showNotification('Hai ricevuto un trasferimento da il player ' .. xPlayer.getName() .. 'di: ' .. importodatrasferire .. '€')
                else
                    xPlayer.showNotification('Non hai abbastanza soldi in banca.')
                end
            else
                xPlayer.showNotification('Importo non valido per il trasferimento.')
            end
        else
            xPlayer.showNotification('IBAN non trovato.')
        end
    end)
end)

--- sql e iban ---

AddEventHandler('onResourceStart', function(resourceName)
    if resourceName ~= GetCurrentResourceName() then
        return
    end

    TriggerEvent('high_bank:generaIban')

    local sqlHighBank = [[
        CREATE TABLE IF NOT EXISTS high_bank (
            identifier LONGTEXT NOT NULL,
            iban VARCHAR(10) UNIQUE NOT NULL
        )
    ]]

    MySQL.Async.execute(sqlHighBank, {}, function(rowsChanged)
        if rowsChanged >= 0 then
            print('Tabella high_bank creata o già essadasdistente.')

        else
            print('Errore nella creazione della tabella high_bank.')
        end
    end)
end)

local function generateIBAN()
    local iban_prefix = Config.PrefissoIban
    local iban_body = ""
    for i = 1, 26 do
        iban_body = iban_body .. math.random(0, 9)
    end
    return iban_prefix .. iban_body
end

local function insertIBANInDatabase(identifier, iban)
    local checkQuery = "SELECT * FROM high_bank WHERE identifier = @identifier"
    MySQL.Async.fetchScalar(checkQuery, {
        ['@identifier'] = identifier
    }, function(existingIBAN)
        if existingIBAN then
            print("IBAN già presente per l'identificatore.")
        else
            local insertQuery = "INSERT INTO high_bank (identifier, iban) VALUES (@identifier, @iban)"
            MySQL.Async.execute(insertQuery, {
                ['@identifier'] = identifier,
                ['@iban'] = iban
            }, function(affectedRows)
                if affectedRows > 0 then
                    print("IBAN inserito con successo nel database.")
                else
                    print("Errore durante l'inserimento dell'IBAN nel database.")
                end
            end)
        end
    end)
end

RegisterNetEvent('high_bank:creaIban')
AddEventHandler('high_bank:creaIban', function ()
    local xPlayer = ESX.GetPlayerFromId(source)
    local iban = generateIBAN()
    insertIBANInDatabase(xPlayer.identifier, iban)
end)

--- carta di credito 


RegisterNetEvent('high_bank:richiediCarta')
AddEventHandler('high_bank:richiediCarta', function()
    local xPlayer = ESX.GetPlayerFromId(source)
    local metadata = {
        identifier = xPlayer.identifier,
        nomecompleto = xPlayer.getName(),
        pin = '1234',
    }

    exports.ox_inventory:AddItem(xPlayer.source, 'cartadicredito', 1, metadata)
end)


ESX.RegisterUsableItem('cartadicredito', function(source, slot, item)
    local xPlayer = ESX.GetPlayerFromId(source)
    if item.metadata then
        TriggerClientEvent('high_bank:usaCarta', source, item.metadata)
    else
        xPlayer.showNotification("Questo carta non è appartenente a nessuno")
    end
end)

RegisterNetEvent('high_bank:cambiaPin')
AddEventHandler('high_bank:cambiaPin', function(nuovopin)
    local xPlayer = ESX.GetPlayerFromId(source)

    local metadataRemove = {
        identifier = xPlayer.identifier,
        nomecompleto = xPlayer.getName(),
        pin = '1234',
    }
    exports.ox_inventory:RemoveItem(xPlayer.source, 'cartadicredito', 1, metadataRemove)
    print(nuovopin)
    print(json.decode(nuovopin))
    local metadataAdd = {
        identifier = xPlayer.identifier,
        nomecompleto = xPlayer.getName(),
        pin = nuovopin,
    }
    exports.ox_inventory:AddItem(xPlayer.source, 'cartadicredito', 1, metadataAdd)
end)

RegisterNetEvent('high_bank:trovainfoPerBnacomat')
AddEventHandler('high_bank:trovainfoPerBnacomat', function(identifier)
    source = source
    local xPlayer = ESX.GetPlayerFromId(source)
    local xPlayerApreBancomat = ESX.GetPlayerFromIdentifier(identifier)
    if not xPlayer then
        return
    end
    if not xPlayerApreBancomat then
        print("Errore: Nessun giocatore trovato con l'identifier " .. identifier)
        return
    end

    local playerIdentifier = identifier

    local query = "SELECT iban FROM high_bank WHERE identifier = @identifier"
    MySQL.Async.fetchScalar(query, {
        ['@identifier'] = playerIdentifier
    }, function(iban)
        if iban then
            local bankMoney = xPlayerApreBancomat.getAccount('bank').money
            TriggerClientEvent('high_bank:inftoperbancomattrovare', xPlayer.source, bankMoney, iban)
        else
            print("Errore: Nessun IBAN trovato per l'identifier " .. playerIdentifier)
        end
    end)
end)