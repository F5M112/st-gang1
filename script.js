let currentGang = null;
let currentMenu = null;

// Listen for messages from client
window.addEventListener('message', function(event) {
    const data = event.data;
    
    switch(data.action) {
        case 'openMenu':
            openMenu(data.type, data.data);
            break;
        case 'updateGangs':
            updateGangs(data.data);
            break;
        case 'updateStatistics':
            updateStatistics(data.data);
            break;
        case 'updateLogs':
            updateLogs(data.data);
            break;
    }
});

function openMenu(type, data) {
    currentMenu = type;
    $('#container').fadeIn(200);
    
    if (type === 'gang') {
        currentGang = data.gang;
        $('#gangMenu').show();
        updateGangUI();
    } else if (type === 'mafia') {
        $('#mafiaMenu').show();
    }
}

function closeMenu() {
    $('#container').fadeOut(200);
    $('#gangMenu').hide();
    $('#mafiaMenu').hide();
    
    $.post('https://gang_system/closeMenu', JSON.stringify({}));
}

// Tab Management
function showTab(tabName) {
    $('.tab-content').removeClass('active');
    $(`#${tabName}`).addClass('active');
    $('.tabs .tab-btn').removeClass('active');
    event.target.classList.add('active');
    
    // Load data based on tab
    if (tabName === 'territories') {
        loadTerritories();
    } else if (tabName === 'wars') {
        loadWars();
    } else if (tabName === 'upgrades') {
        loadUpgrades();
    } else if (tabName === 'leaderboard') {
        loadLeaderboard();
    }
}

function showMafiaTab(tabName) {
    $('.tab-content').removeClass('active');
    $(`#mafia-${tabName}`).addClass('active');
    $('.tabs .tab-btn').removeClass('active');
    event.target.classList.add('active');
    
    if (tabName === 'gangs') {
        loadMafiaGangs();
    } else if (tabName === 'wars') {
        loadMafiaWars();
    } else if (tabName === 'territories') {
        loadMafiaTerritories();
    }
}

// Update Gang UI
function updateGangUI() {
    if (!currentGang) return;
    
    $('#gangName').text(currentGang.label);
    $('#gangLeader').text(currentGang.leader);
    $('#gangLevel').text(currentGang.level);
    $('#gangReputation').text(currentGang.reputation);
    $('#gangMemberCount').text(currentGang.members.length);
    $('#gangKills').text(currentGang.kills);
    $('#gangDeaths').text(currentGang.deaths);
    $('#gangBalance').text('$' + currentGang.balance.toLocaleString());
    $('#vaultBalance').text('$' + currentGang.balance.toLocaleString());
    
    // Update members list
    updateMembersList();
}

function updateMembersList() {
    const membersList = $('#membersList');
    membersList.empty();
    
    if (currentGang && currentGang.members) {
        currentGang.members.forEach(member => {
            const rankName = getRankName(member.rank);
            const memberItem = `
                <div class="list-item">
                    <div style="display: flex; justify-content: space-between; align-items: center;">
                        <div>
                            <span class="label">ID:</span> <span class="value">${member.identifier}</span><br>
                            <span class="label">Rank:</span> <span class="value">${rankName}</span><br>
                            <span class="label">Joined:</span> <span class="value">${member.joined_at}</span>
                        </div>
                        <div>
                            ${member.identifier !== currentGang.leader ? 
                                `<button class="btn-danger" onclick="kickMember('${member.identifier}')">KICK</button>` 
                                : '<span class="value">LEADER</span>'}
                        </div>
                    </div>
                </div>
            `;
            membersList.append(memberItem);
        });
    }
}

function getRankName(rankLevel) {
    const ranks = ['Recruit', 'Member', 'Co-Leader', 'Leader'];
    return ranks[rankLevel - 1] || 'Unknown';
}

// Gang Actions
function inviteMember() {
    const playerId = $('#invitePlayerId').val();
    if (playerId) {
        $.post('https://gang_system/inviteMember', JSON.stringify({
            playerId: playerId
        }));
        $('#invitePlayerId').val('');
    }
}

function kickMember(identifier) {
    $.post('https://gang_system/kickMember', JSON.stringify({
        identifier: identifier
    }));
}

function deposit() {
    const amount = $('#depositAmount').val();
    if (amount && amount > 0) {
        $.post('https://gang_system/deposit', JSON.stringify({
            amount: amount
        }));
        $('#depositAmount').val('');
    }
}

function withdraw() {
    const amount = $('#withdrawAmount').val();
    if (amount && amount > 0) {
        $.post('https://gang_system/withdraw', JSON.stringify({
            amount: amount
        }));
        $('#withdrawAmount').val('');
    }
}

function setVaultLocation() {
    $.post('https://gang_system/setVaultLocation', JSON.stringify({}));
}

function declareWar() {
    const targetGangId = $('#warTargetGang').val();
    if (targetGangId) {
        $.post('https://gang_system/declareWar', JSON.stringify({
            gangId: targetGangId
        }));
    }
}

// Load Functions
function loadTerritories() {
    // This would be populated from server
    const territoriesList = $('#territoriesList');
    territoriesList.html('<div class="value">Loading territories...</div>');
}

function loadWars() {
    const warsList = $('#warsList');
    warsList.html('<div class="value">Loading wars...</div>');
}

function loadUpgrades() {
    const upgradesList = $('#upgradesList');
    upgradesList.empty();
    
    const upgrades = {
        vault_size: { name: 'Vault Size', levels: 4 },
        tax_reduction: { name: 'Tax Reduction', levels: 3 },
        capture_speed: { name: 'Capture Speed', levels: 3 },
        passive_income: { name: 'Passive Income', levels: 3 },
        member_slots: { name: 'Member Slots', levels: 4 }
    };
    
    for (const [key, upgrade] of Object.entries(upgrades)) {
        const upgradeCard = `
            <div class="upgrade-card">
                <div class="upgrade-header">${upgrade.name}</div>
                <div class="upgrade-level">Current Level: ${currentGang.upgrades[key] || 0}</div>
                <button class="btn-primary" onclick="purchaseUpgrade('${key}', ${(currentGang.upgrades[key] || 0) + 1})">
                    UPGRADE
                </button>
            </div>
        `;
        upgradesList.append(upgradeCard);
    }
}

function purchaseUpgrade(upgradeType, level) {
    $.post('https://gang_system/purchaseUpgrade', JSON.stringify({
        upgradeType: upgradeType,
        level: level
    }));
}

function loadLeaderboard() {
    showLeaderboard('money');
}

function showLeaderboard(category) {
    const leaderboardList = $('#leaderboardList');
    leaderboardList.html('<div class="value">Loading leaderboard...</div>');
}

// Mafia Functions
function updateGangs(gangs) {
    loadMafiaGangs(gangs);
    
    // Update war target dropdown
    const dropdown = $('#warTargetGang');
    dropdown.empty();
    dropdown.append('<option value="">Select Gang</option>');
    
    for (const [id, gang] of Object.entries(gangs)) {
        if (currentGang && gang.id !== currentGang.id) {
            dropdown.append(`<option value="${gang.id}">${gang.label}</option>`);
        }
    }
}

function loadMafiaGangs(gangs = null) {
    const gangsList = $('#mafiaGangsList');
    gangsList.empty();
    
    if (!gangs) {
        gangsList.html('<div class="value">Loading gangs...</div>');
        return;
    }
    
    for (const [id, gang] of Object.entries(gangs)) {
        const gangItem = `
            <div class="list-item">
                <div style="display: flex; justify-content: space-between; align-items: center;">
                    <div>
                        <span class="label">NAME:</span> <span class="value">${gang.label}</span><br>
                        <span class="label">LEADER:</span> <span class="value">${gang.leader}</span><br>
                        <span class="label">LEVEL:</span> <span class="value">${gang.level}</span><br>
                        <span class="label">MEMBERS:</span> <span class="value">${gang.members.length}</span><br>
                        <span class="label">BALANCE:</span> <span class="value">$${gang.balance.toLocaleString()}</span><br>
                        <span class="label">REPUTATION:</span> <span class="value">${gang.reputation}</span>
                    </div>
                    <div style="display: flex; flex-direction: column; gap: 5px;">
                        <button class="btn-primary" onclick="viewGangLogs(${gang.id})">LOGS</button>
                        <button class="btn-secondary" onclick="showChangeLeaderForm(${gang.id})">CHANGE LEADER</button>
                        <button class="btn-success" onclick="showGiveMoneyForm(${gang.id})">GIVE MONEY</button>
                        <button class="btn-danger" onclick="withdrawFromGang(${gang.id})">WITHDRAW</button>
                        <button class="btn-danger" onclick="resetGang(${gang.id})">RESET</button>
                        <button class="btn-danger" onclick="deleteGang(${gang.id})">DELETE</button>
                    </div>
                </div>
            </div>
        `;
        gangsList.append(gangItem);
    }
}

function updateStatistics(stats) {
    $('#statTotalGangs').text(stats.totalGangs);
    $('#statTotalMembers').text(stats.totalMembers);
    $('#statTotalMoney').text('$' + stats.totalMoney.toLocaleString());
    $('#statActiveWars').text(stats.activeWars);
    $('#statTerritories').text(stats.capturedTerritories);
}

function showCreateGangForm() {
    const form = prompt('Format: gangName|gangLabel|leaderIdentifier');
    if (form) {
        const parts = form.split('|');
        if (parts.length === 3) {
            $.post('https://gang_system/createGang', JSON.stringify({
                name: parts[0],
                label: parts[1],
                leaderIdentifier: parts[2]
            }));
        }
    }
}

function deleteGang(gangId) {
    if (confirm('Are you sure you want to delete this gang?')) {
        $.post('https://gang_system/deleteGang', JSON.stringify({
            gangId: gangId
        }));
    }
}

function showChangeLeaderForm(gangId) {
    const identifier = prompt('Enter new leader identifier:');
    if (identifier) {
        $.post('https://gang_system/changeLeader', JSON.stringify({
            gangId: gangId,
            newLeaderIdentifier: identifier
        }));
    }
}

function resetGang(gangId) {
    if (confirm('Are you sure you want to reset this gang?')) {
        $.post('https://gang_system/resetGang', JSON.stringify({
            gangId: gangId
        }));
    }
}

function withdrawFromGang(gangId) {
    const amount = prompt('Enter amount to withdraw:');
    if (amount && amount > 0) {
        $.post('https://gang_system/withdrawFromGang', JSON.stringify({
            gangId: gangId,
            amount: parseInt(amount)
        }));
    }
}

function showGiveMoneyForm(gangId) {
    const amount = prompt('Enter amount to give:');
    if (amount && amount > 0) {
        $.post('https://gang_system/giveMoneyToGang', JSON.stringify({
            gangId: gangId,
            amount: parseInt(amount)
        }));
    }
}

function setGlobalTax() {
    const tax = $('#globalTax').val();
    if (tax && tax >= 0 && tax <= 50) {
        $.post('https://gang_system/setTax', JSON.stringify({
            tax: parseInt(tax)
        }));
    }
}

function viewGangLogs(gangId) {
    $.post('https://gang_system/getGangLogs', JSON.stringify({
        gangId: gangId
    }));
}

function updateLogs(logs) {
    alert('Logs: ' + JSON.stringify(logs, null, 2));
}

function loadMafiaWars() {
    const warsList = $('#mafiaWarsList');
    warsList.html('<div class="value">Loading wars...</div>');
}

function loadMafiaTerritories() {
    const territoriesList = $('#mafiaTerritoriesList');
    territoriesList.html('<div class="value">Loading territories...</div>');
}

// ESC to close
document.addEventListener('keyup', function(e) {
    if (e.key === 'Escape') {
        closeMenu();
    }
});