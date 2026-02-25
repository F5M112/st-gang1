Config = {}

-- Mafia Settings
Config.MafiaIdentifiers = {
    'steam:110000149864a14', -- Replace with actual mafia boss identifier
}

Config.MafiaTax = 15 -- Percentage tax from all gang income

-- Gang Settings
Config.DefaultGangLevel = 1
Config.MaxGangLevel = 10
Config.DefaultVaultSize = 50000
Config.DefaultMemberSlots = 10
Config.MaxMemberSlots = 50

Config.GangRanks = {
    {name = 'Leader', level = 4, canInvite = true, canKick = true, canWithdraw = true, canUpgrade = true},
    {name = 'Co-Leader', level = 3, canInvite = true, canKick = true, canWithdraw = true, canUpgrade = false},
    {name = 'Member', level = 2, canInvite = false, canKick = false, canWithdraw = false, canUpgrade = false},
    {name = 'Recruit', level = 1, canInvite = false, canKick = false, canWithdraw = false, canUpgrade = false},
}

-- Territory Settings
Config.Territories = {
    {
        name = 'Grove Street',
        coords = vector3(127.82, -1930.07, 21.38),
        radius = 100.0,
        blip = {sprite = 437, color = 2, scale = 1.0},
        captureTime = 300,
        passiveIncome = 5000,
        minMembers = 3,
        cooldown = 3600
    },
    {
        name = 'Sandy Shores',
        coords = vector3(1853.24, 3686.85, 34.27),
        radius = 150.0,
        blip = {sprite = 437, color = 3, scale = 1.0},
        captureTime = 400,
        passiveIncome = 7500,
        minMembers = 4,
        cooldown = 3600
    },
    {
        name = 'Paleto Bay',
        coords = vector3(-105.47, 6528.38, 29.92),
        radius = 120.0,
        blip = {sprite = 437, color = 5, scale = 1.0},
        captureTime = 350,
        passiveIncome = 6500,
        minMembers = 3,
        cooldown = 3600
    },
    {
        name = 'La Mesa',
        coords = vector3(731.13, -1183.37, 24.29),
        radius = 100.0,
        blip = {sprite = 437, color = 1, scale = 1.0},
        captureTime = 300,
        passiveIncome = 5500,
        minMembers = 3,
        cooldown = 3600
    },
    {
        name = 'Vespucci Beach',
        coords = vector3(-1213.07, -1456.94, 4.38),
        radius = 130.0,
        blip = {sprite = 437, color = 6, scale = 1.0},
        captureTime = 450,
        passiveIncome = 8000,
        minMembers = 5,
        cooldown = 3600
    }
}

-- War Settings
Config.War = {
    duration = 1800,
    cooldown = 7200,
    minMembers = 3,
    killReward = 100,
    winReward = 5000,
    winReputation = 1000,
    loseReputation = 500,
    maxActiveWars = 3
}

-- Upgrade System
Config.Upgrades = {
    vault_size = {
        name = 'Vault Size',
        levels = {
            {cost = 50000, value = 100000},
            {cost = 100000, value = 200000},
            {cost = 200000, value = 500000},
            {cost = 500000, value = 1000000},
        }
    },
    tax_reduction = {
        name = 'Tax Reduction',
        levels = {
            {cost = 75000, value = 2},
            {cost = 150000, value = 5},
            {cost = 300000, value = 10},
        }
    },
    capture_speed = {
        name = 'Capture Speed',
        levels = {
            {cost = 60000, value = 10},
            {cost = 120000, value = 20},
            {cost = 250000, value = 35},
        }
    },
    passive_income = {
        name = 'Passive Income Boost',
        levels = {
            {cost = 80000, value = 10},
            {cost = 160000, value = 25},
            {cost = 320000, value = 50},
        }
    },
    member_slots = {
        name = 'Member Slots',
        levels = {
            {cost = 40000, value = 5},
            {cost = 80000, value = 10},
            {cost = 160000, value = 15},
            {cost = 320000, value = 20},
        }
    }
}

-- Leaderboard Settings
Config.Leaderboard = {
    updateInterval = 300000,
    weeklyResetDay = 1,
    weeklyRewards = {
        [1] = {money = 100000, reputation = 5000},
        [2] = {money = 75000, reputation = 3000},
        [3] = {money = 50000, reputation = 2000},
    }
}

-- Reputation System
Config.Reputation = {
    killPlayer = 10,
    captureTerritory = 500,
    winWar = 1000,
    loseWar = -500,
    levelUpBonus = 200
}

Config.Notifications = {
    success = 'success',
    error = 'error',
    info = 'primary'
}

Config.UIKeys = {
    openMenu = 'F6',
    openMafiaMenu = 'F7'
}

