local packets = require('packets');
local config = require('config');
local party = {{},{},{},{},{}}; -- array of buff tables

return {

  ---------------------------------------------------------------------------------------------------
  -- func: process
  -- desc: process party related stuff
  ---------------------------------------------------------------------------------------------------
  process = function(self, id, size, packet)
    if (id == packets.inc.PACKET_PARTY_INVITE) then
      local type = struct.unpack('B', packet, 0x0B + 1);
      local actor = struct.unpack('s', packet, 0x0C + 1);
      if (type == packets.INVITE_TYPE_PARTY and actor == config:get().leader) then
        AshitaCore:GetChatManager():QueueCommand('/join', 0);
      elseif (type == packets.INVITE_TYPE_PARTY) then
        print('actor: ' .. actor .. ' leader: ' .. config:get().leader);
      end
    end

    if (id == packets.inc.PACKET_PARTY_STATUS_EFFECT) then
      -- party buff entry (pbe): [pid-4][pidx-2][unk-2][mask-8][buffs-32]
      -- packet: [header-4][pbe-48][pbe-48][pbe-48][pbe-48][pbe-48]

      for pidx = 0, 4, 1 do
        local offset = 4 + (pidx * 48);
        local playerid = struct.unpack('I4', packet, offset);
        local partyidx = struct.unpack('I2', packet, offset + 4);
        local unk = struct.unpack('I2', packet, offset + 6);
        local mask = struct.unpack('I8', packet, offset + 8);

        local iparty = AshitaCore:GetDataManager():GetParty()
        -- print(partyidx .. ' ' .. iparty:GetMemberNumber(playeridx) .. ' ' .. iparty:GetMemberIndex(playeridx));

        -- Try see if the memberindex is the correct slot to put them in.
        local playeridx = pidx + 1;
        for i = 1, 5 do
          if (iparty:GetMemberIndex(i) == pidx + 1) then
            playeridx = i;
            break;
          end
        end
        local buffs = {};
        party[playeridx] = buffs;
        -- print(playeridx .. ',' .. tostring(party[playeridx]));
        for buff = 0, 31, 1 do
          -- 64 total bits in the mask
          local shifted = bit.rshift(mask, 62 - (2 * buff)); -- move the 2 bits all the way to the right
          shifted = bit.band(shifted, 3) -- only the last 2 bits

          local base = struct.unpack('I1', packet, offset + 16 + buff);
          local buffid = (256 * shifted) + base;

          if (base ~= 0xFF and base ~= 0x00) then
            -- print("Party member: " .. pidx .. " buff: " .. buffid);
            if (buffs[buffid] == nil) then
              buffs[buffid] = true;
            elseif (buffs[buffid] == true) then
              buffs[buffid] = 2;
            else
              buffs[buffid] = buffs[buffid] + 1;
            end
          end
        end
      end
      self:DumpBuffs();
    end
  end,

  DumpBuffs = function(self)
    self:PartyBuffs(function(i, buffs)
      if (buffs ~= nil) then
        local list = {};
        for k, v in pairs(buffs) do
          table.insert(list, k);
        end
        table.sort(list);
        print('member'.. i .. ': ' .. ashita.settings.JSON:encode_pretty(list, nil, {}));
      end
    end);
  end,

  ---------------------------------------------------------------------------------------------------
  -- func: GetBuffs
  -- desc: Gets the buffs for a party member (player == index 0)
  ---------------------------------------------------------------------------------------------------
  GetBuffs = function(self, index)
    if (index == 0) then -- for the local player
      local buffs = {};
      local bufftbl = AshitaCore:GetDataManager():GetPlayer():GetBuffs();
      for k, v in pairs(bufftbl) do
        if (v ~= -1) then
          buffs[v] = true;
        end
      end
      return buffs;
    else
      return party[index];
    end
  end,

  -- Scan the party and perform a callback for each player,
  -- with the table of buffs for that player
  -- @param cb The callback, will be passed index of party member (0 == self), and buff table
  --           return true from the cb to stop party member iteration.
  PartyBuffs = function(self, cb)
    for i = 0, 5 do -- include current player
      local buffs = self:GetBuffs(i);
      if (cb(i, buffs) == true) then
        break;
      end
    end
  end,

  GetHPP = function(self, i)
    local iparty = AshitaCore:GetDataManager():GetParty();
    local player = GetPlayerEntity();
    if (i == 0 and player) then
      return player.HealthPercent;
    else
      return iparty:GetMemberCurrentHPP(i);
    end
  end
};
