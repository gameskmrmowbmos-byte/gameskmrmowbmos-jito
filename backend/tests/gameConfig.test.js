const test = require('node:test');
const assert = require('node:assert/strict');
const {
  analyzeNumberSetEntries,
  analyzeStandardPanaMaster,
  assertNoCloseSessionJackpots,
  generateFullSangam,
  normalizeAutoItem,
  normalizeManualItem,
  serializeGameConfig,
  standardGameConfigPayload,
  standardPannaMotorNumberSetPayload,
  standardPannaNumberSetPayload,
} = require('../src/services/gameConfig.service');

test('Close session rejects jackpot entries', () => {
  assert.doesNotThrow(() => assertNoCloseSessionJackpots('Open', [
    { isJackpot: true },
  ]));
  assert.doesNotThrow(() => assertNoCloseSessionJackpots('Close', [
    { isJackpot: false },
  ]));
  assert.throws(
    () => assertNoCloseSessionJackpots('Close', [
      { isJackpot: false },
      { isJackpot: true },
    ]),
    /Item 2 Jackpot is not allowed in Close session/,
  );
  assert.throws(
    () => assertNoCloseSessionJackpots('Close', [
      { components: { jackpotEntries: [{ number: '1', amount: '5' }] } },
    ]),
    /Item 1 Jackpot is not allowed in Close session/,
  );
});

test('manual Family entries keep base amount and calculate family total', () => {
  assert.deepEqual(normalizeManualItem({
    type: 'Patti',
    number: 'F178',
    amount: 1,
  }, 0), {
    type: 'Patti',
    number: '178',
    amount: 8,
    mode: 'Manual',
    betType: 'PANNA',
    betSubtype: 'FAMILY',
    isJackpot: false,
    components: {
      displayAmount: '1',
      family: true,
      familyMultiplier: 8,
    },
  });

  assert.equal(normalizeManualItem({
    type: 'Patti',
    number: '227F',
    amount: 1,
  }, 0).amount, 4);
  assert.equal(normalizeManualItem({
    type: 'Patti',
    number: '060F',
    amount: 1,
  }, 0).amount, 6);
  assert.equal(normalizeManualItem({
    type: 'Patti',
    number: '557F',
    amount: 1,
  }, 0).amount, 6);
});

test('manual Jodi Family entries calculate 4x for same family and 8x otherwise', () => {
  assert.deepEqual(normalizeManualItem({
    type: 'Jodi',
    number: '16F',
    amount: 1,
  }, 0), {
    type: 'Jodi',
    number: '16',
    amount: 4,
    mode: 'Manual',
    betType: 'JODI',
    betSubtype: 'FAMILY',
    isJackpot: false,
    components: {
      displayAmount: '1',
      family: true,
      familyMultiplier: 4,
    },
  });

  assert.equal(normalizeManualItem({
    type: 'Jodi',
    number: '21F',
    amount: 1,
  }, 0).amount, 8);
  assert.equal(normalizeManualItem({
    type: 'Jodi',
    number: '61F',
    amount: 1,
  }, 0).amount, 4);
});

test('manual Family uses display amount as base when amount is already calculated', () => {
  assert.deepEqual(normalizeManualItem({
    type: 'Patti',
    number: '178',
    amount: 8,
    components: {
      family: true,
      displayAmount: '1',
    },
  }, 0), {
    type: 'Patti',
    number: '178',
    amount: 8,
    mode: 'Manual',
    betType: 'PANNA',
    betSubtype: 'FAMILY',
    isJackpot: false,
    components: {
      displayAmount: '1',
      family: true,
      familyMultiplier: 8,
    },
  });
});

test('manual CP Jodi entries keep base amount and calculate 10x total', () => {
  assert.deepEqual(normalizeManualItem({
    type: 'Jodi',
    number: '12 CP',
    amount: 1,
  }, 0), {
    type: 'Jodi',
    number: '12',
    amount: 10,
    mode: 'Manual',
    betType: 'JODI',
    betSubtype: 'CP',
    isJackpot: false,
    components: {
      displayAmount: '1',
      cp: true,
      cpMultiplier: 10,
    },
  });

  assert.deepEqual(normalizeManualItem({
    type: 'Jodi',
    number: '12',
    amount: 10,
    components: {
      cp: true,
      displayAmount: '1',
    },
  }, 0), {
    type: 'Jodi',
    number: '12',
    amount: 10,
    mode: 'Manual',
    betType: 'JODI',
    betSubtype: 'CP',
    isJackpot: false,
    components: {
      displayAmount: '1',
      cp: true,
      cpMultiplier: 10,
    },
  });

  assert.equal(normalizeManualItem({
    type: 'Jodi',
    number: '12 CP',
    amount: 1,
  }, 0, 'Close').amount, 10);
});

test('manual CP Jodi accepts only ascending 2 digit Jodi numbers', () => {
  assert.equal(normalizeManualItem({
    type: 'Jodi',
    number: 'CP90',
    amount: 1,
  }, 0).amount, 10);

  assert.throws(
    () => normalizeManualItem({
      type: 'Jodi',
      number: '21 CP',
      amount: 1,
    }, 0),
    /ascending/,
  );

  assert.throws(
    () => normalizeManualItem({
      type: 'Patti',
      number: '123 CP',
      amount: 1,
    }, 0),
    /CP can be used only with Jodi/,
  );
});

test('manual Common single entries keep base amount and calculate 36x total', () => {
  assert.deepEqual(normalizeManualItem({
    type: 'Single',
    number: '5cm',
    amount: 1,
  }, 0), {
    type: 'Single',
    number: '5',
    amount: 36,
    mode: 'Manual',
    betType: 'SINGLE',
    betSubtype: 'COMMON',
    isJackpot: false,
    components: {
      displayAmount: '1',
      common: true,
      commonMultiplier: 36,
    },
  });

  assert.equal(normalizeManualItem({
    type: 'Single',
    number: '5',
    amount: 36,
    components: {
      common: true,
      displayAmount: '1',
    },
  }, 0).amount, 36);

  assert.equal(normalizeManualItem({
    type: 'Single',
    number: '5cm',
    amount: 1,
  }, 0, 'Close').amount, 36);

  assert.throws(
    () => normalizeManualItem({
      type: 'Single',
      number: '55cm',
      amount: 1,
    }, 0),
    /Common number must be single digit/,
  );
});

test('manual simple Jodi preserves descending number order', () => {
  assert.deepEqual(normalizeManualItem({
    type: 'Jodi',
    number: '21',
    amount: 1,
  }, 0), {
    type: 'Jodi',
    number: '21',
    amount: 1,
    mode: 'Manual',
    isJackpot: false,
  });
});

test('number-set analysis preserves string values and reports duplicates', () => {
  const analysis = analyzeNumberSetEntries(
    [
      { value: '128', column: 1 },
      { value: '459', column: 8 },
      { value: '459', column: 9 },
      { value: '04', column: 2 },
    ],
    3,
  );

  assert.equal(analysis.totalSuppliedEntries, 4);
  assert.equal(analysis.uniqueEntries, 3);
  assert.deepEqual(analysis.duplicateValues, [
    { value: '459', count: 2, columns: [8, 9] },
  ]);
  assert.deepEqual(analysis.invalidStringLengths, [
    { index: 3, value: '04', length: 2 },
  ]);
});

test('standard config validates Single and Jodi as central string values', () => {
  const config = standardGameConfigPayload();

  assert.deepEqual(normalizeAutoItem({
    mode: 'AUTO',
    betType: 'SINGLE',
    number: '4',
    amount: 10,
  }, config, 0), {
    type: 'Single',
    number: '4',
    amount: 10,
    mode: 'Auto',
    betType: 'SINGLE',
    isJackpot: false,
  });

  assert.deepEqual(normalizeAutoItem({
    mode: 'AUTO',
    betType: 'JODI',
    number: '04',
    amount: 20,
  }, config, 0), {
    type: 'Jodi',
    number: '04',
    amount: 20,
    mode: 'Auto',
    betType: 'JODI',
    isJackpot: false,
  });
});

test('Open Jodi rejects Jackpot for manual and auto entries', () => {
  const config = standardGameConfigPayload();

  assert.throws(
    () => normalizeManualItem({
      type: 'Jodi',
      number: '21',
      amount: 10,
      isJackpot: true,
    }, 0, 'Open'),
    /Jackpot is not allowed for Jodi/,
  );

  assert.throws(
    () => normalizeManualItem({
      type: 'Jodi',
      number: '21',
      amount: 10,
      components: {
        jackpotEntries: [{ number: '4', amount: '1' }],
      },
    }, 0, 'Open'),
    /Jackpot is not allowed for Jodi/,
  );

  assert.throws(
    () => normalizeAutoItem({
      mode: 'AUTO',
      betType: 'JODI',
      number: '04',
      amount: 20,
      isJackpot: true,
    }, config, 0),
    /Jackpot is not allowed for Jodi/,
  );
});

test('standard Pana number set preserves supplied 220 master strings', () => {
  const { payload, analysis } = standardPannaNumberSetPayload();

  assert.equal(payload.code, 'STANDARD_220_PANNA');
  assert.equal(analysis.totalSuppliedEntries, 220);
  assert.equal(analysis.uniqueEntries, 220);
  assert.deepEqual(analysis.duplicateValues, []);
  assert.deepEqual(analysis.invalidStringLengths, []);
  assert.equal(payload.groups.find((group) => group.ank === '0').numbers[0], '000');
  assert.equal(payload.values.find((entry) => entry.value === '000').value, '000');
  assert.equal(typeof payload.values.find((entry) => entry.value === '000').value, 'string');
});

test('standard Pana master validates exactly 22 strings per digit', () => {
  const analysis = analyzeStandardPanaMaster();

  assert.equal(analysis.totalMasterPanas, 220);
  assert.equal(analysis.uniqueMasterPanas, 220);
  assert.deepEqual(analysis.countsByDigit, {
    0: 22,
    1: 22,
    2: 22,
    3: 22,
    4: 22,
    5: 22,
    6: 22,
    7: 22,
    8: 22,
    9: 22,
  });
  assert.deepEqual(analysis.duplicateValues, []);
  assert.deepEqual(analysis.invalidStringLengths, []);
  assert.deepEqual(analysis.wrongDigitAssignments, []);
  assert.deepEqual(analysis.invalidDigitCounts, []);
});

test('standard config validates supplied Panna subtype membership', () => {
  const config = standardGameConfigPayload();

  assert.deepEqual(normalizeAutoItem({
    mode: 'AUTO',
    betType: 'PANNA',
    betSubtype: 'Pana',
    number: '145',
    amount: 10,
  }, config, 0), {
    type: 'Patti',
    number: '145',
    amount: 10,
    mode: 'Auto',
    betType: 'PANNA',
    betSubtype: 'PANA',
    isJackpot: false,
  });

  assert.deepEqual(normalizeAutoItem({
    mode: 'AUTO',
    betType: 'PANNA',
    betSubtype: 'Pana',
    number: '334',
    amount: 20,
  }, config, 0), {
    type: 'Patti',
    number: '334',
    amount: 20,
    mode: 'Auto',
    betType: 'PANNA',
    betSubtype: 'PANA',
    isJackpot: false,
  });

  assert.deepEqual(normalizeAutoItem({
    mode: 'AUTO',
    betType: 'PANNA',
    betSubtype: 'SP',
    number: '128',
    amount: 10,
  }, config, 0), {
    type: 'Patti',
    number: '128',
    amount: 10,
    mode: 'Auto',
    betType: 'PANNA',
    betSubtype: 'SP',
    isJackpot: false,
  });

  assert.deepEqual(normalizeAutoItem({
    mode: 'AUTO',
    betType: 'PANNA',
    betSubtype: 'DP',
    number: '550',
    amount: 20,
  }, config, 0), {
    type: 'Patti',
    number: '550',
    amount: 20,
    mode: 'Auto',
    betType: 'PANNA',
    betSubtype: 'DP',
    isJackpot: false,
  });

  assert.deepEqual(normalizeAutoItem({
    mode: 'AUTO',
    betType: 'PANNA',
    betSubtype: 'TP',
    number: '000',
    amount: 30,
  }, config, 0), {
    type: 'Patti',
    number: '000',
    amount: 30,
    mode: 'Auto',
    betType: 'PANNA',
    betSubtype: 'TP',
    isJackpot: false,
  });

  assert.throws(
    () => normalizeAutoItem({
      mode: 'AUTO',
      betType: 'PANNA',
      betSubtype: 'SP',
      number: '145',
      amount: 10,
    }, config, 0),
    /not configured/,
  );
});

test('standard config exposes supplied 220 numbers only in Pana subtype', () => {
  const config = standardGameConfigPayload();
  const { payload } = standardPannaNumberSetPayload();
  const serialized = serializeGameConfig(config, payload);
  const panna = serialized.autoTypes.find((type) => type.id === 'panna');
  const spMotorType = serialized.autoTypes.find((type) => type.id === 'sp_motor');
    const pana = panna.subtypes.find((subtype) => subtype.id === 'pana');
  const sp = serialized.autoTypes.find((type) => type.id === 'sp');
  const cp = serialized.autoTypes.find((type) => type.id === 'cp');
  const mp = serialized.autoTypes.find((type) => type.id === 'mp');

  assert.deepEqual(panna.subtypes.map((subtype) => subtype.id), ['pana']);
  assert.equal(panna.subtypes.length, 1);
  assert.equal(spMotorType.label, 'SP Motor');
    assert.deepEqual(
    spMotorType.subtypes.map((subtype) => subtype.label),
    ['1234', '12345', '123456', '1234567', '12345678', '123456789', '1234567890'],
  );
    assert.equal(pana.label, 'Pana');
  assert.equal(cp.label, 'CP');
  assert.equal(mp.label, 'MP');
  assert.equal(cp.enabled, true);
  assert.equal(mp.enabled, true);
  assert.equal(cp.options.length, 220);
  assert.equal(mp.options.length, 220);
  assert.equal(pana.options.length, 220);
  assert.equal(new Set(pana.options.map((option) => option.value)).size, 220);
  assert.deepEqual(
    pana.options.slice(0, 3).map((option) => [option.value, option.column]),
    [
      ['100', 1],
      ['119', 1],
      ['128', 1],
    ],
  );
  assert.equal(pana.options.some((option) => option.value === '145'), true);
  assert.equal(pana.options.some((option) => option.value === '334'), true);
  assert.equal(cp.options.find((option) => option.value === '578').column, 10);
  assert.equal(mp.options.find((option) => option.value === '123').column, 6);
  assert.deepEqual(
    pana.options
      .filter((option) => option.column === 10)
      .slice(0, 3)
      .map((option) => option.value),
    ['000', '118', '127'],
  );
  assert.deepEqual(
    sp.options
      .filter((option) => option.value === '279')
      .map((option) => option.column),
    [8, undefined],
  );
  assert.equal(sp.options.some((option) => option.value === '145'), false);

  const spMotor = spMotorType.subtypes.find((subtype) => subtype.id === 'sp_motor_12345');
  assert.equal(spMotor.label, '12345');
  assert.equal(spMotor.options.length, 10);
  assert.deepEqual(spMotor.options.slice(0, 3).map((option) => option.value), [
    '123',
    '124',
    '125',
  ]);
});

test('Full Sangam generator reproduces reference Jodi 00-09 counts and edges', () => {
  const expectedEdges = {
    '00': ['000-000', '677-677'],
    '01': ['000-100', '677-777'],
    '02': ['000-110', '677-778'],
    '03': ['000-111', '677-788'],
    '04': ['000-112', '677-888'],
    '05': ['000-113', '677-889'],
    '06': ['000-114', '677-899'],
    '07': ['000-115', '677-999'],
    '08': ['000-116', '677-990'],
    '09': ['000-117', '677-900'],
  };

  let total = 0;
  for (const [jodi, [first, last]] of Object.entries(expectedEdges)) {
    const generated = generateFullSangam(jodi[0], jodi[1]);
    total += generated.length;

    assert.equal(generated.length, 484);
    assert.equal(generated[0].value, first);
    assert.equal(generated.at(-1).value, last);
    assert.equal(generated[0].jodi, jodi);
    assert.equal(typeof generated[0].openPana, 'string');
    assert.equal(typeof generated[0].closePana, 'string');
  }

  assert.equal(total, 4840);
});

test('standard config exposes Full Sangam Jodi subtypes without storing flat values', () => {
  const config = standardGameConfigPayload();
  const { payload } = standardPannaNumberSetPayload();
  const serialized = serializeGameConfig(config, payload);
  const fullSangam = serialized.autoTypes.find((type) => type.id === 'full_sangam');
  const jodi01 = fullSangam.subtypes.find((subtype) => subtype.id === '01');

  assert.equal(fullSangam.enabled, true);
  assert.equal(fullSangam.requiresSubtype, true);
  assert.equal(fullSangam.values.length, 0);
  assert.equal(fullSangam.options.length, 0);
  assert.deepEqual(fullSangam.subtypes.map((subtype) => subtype.id), [
    '00',
    '01',
    '02',
    '03',
    '04',
    '05',
    '06',
    '07',
    '08',
    '09',
  ]);
  assert.equal(fullSangam.rules.totalGeneratedForConfiguredJodis, 4840);
  assert.equal(jodi01.options.length, 484);
  assert.equal(jodi01.options[0].value, '000-100');
  assert.equal(jodi01.options.at(-1).value, '677-777');
});

test('standard config validates Full Sangam generated Jodi membership', () => {
  const config = standardGameConfigPayload();

  assert.deepEqual(normalizeAutoItem({
    mode: 'AUTO',
    betType: 'FULL_SANGAM',
    betSubtype: '01',
    number: '000-100',
    amount: 100,
  }, config, 0), {
    type: 'Full Sangam',
    number: '000-100',
    amount: 100,
    mode: 'Auto',
    betType: 'FULL_SANGAM',
    betSubtype: '01',
    components: {
      jodi: '01',
      openPana: '000',
      closePana: '100',
    },
  });

  assert.deepEqual(normalizeAutoItem({
    mode: 'AUTO',
    betType: 'Full Sangam',
    betSubtype: '01',
    number: '118-128',
    amount: 50,
  }, config, 1), {
    type: 'Full Sangam',
    number: '118-128',
    amount: 50,
    mode: 'Auto',
    betType: 'FULL_SANGAM',
    betSubtype: '01',
    components: {
      jodi: '01',
      openPana: '118',
      closePana: '128',
    },
  });

  assert.throws(
    () => normalizeAutoItem({
      mode: 'AUTO',
      betType: 'FULL_SANGAM',
      betSubtype: '05',
      number: '000-100',
      amount: 100,
    }, config, 0),
    /expected 01/,
  );
});

test('manual BZ Full Sangam keeps display amount while total uses bazar multiplier', () => {
  assert.deepEqual(normalizeManualItem({
    type: 'Full Sangam',
    number: '118-128 bz',
    amount: 1,
  }, 0), {
    type: 'Full Sangam',
    number: '118-128',
    amount: 10,
    mode: 'Manual',
    isJackpot: false,
    components: {
      displayAmount: '1',
      bazar: true,
    },
  });

  assert.deepEqual(normalizeManualItem({
    type: 'Full Sangam',
    number: '118-128',
    amount: 10,
    components: {
      bazar: true,
      displayAmount: '1',
    },
  }, 0), {
    type: 'Full Sangam',
    number: '118-128',
    amount: 10,
    mode: 'Manual',
    isJackpot: false,
    components: {
      displayAmount: '1',
      bazar: true,
    },
  });
});

test('Close session rejects Jackpot, Jodi, Sangam, and BZ entries', () => {
  assert.throws(
    () => normalizeManualItem({
      type: 'Single',
      number: '4',
      amount: 10,
      isJackpot: true,
    }, 0, 'Close'),
    /Jackpot is not allowed in Close session/,
  );

  assert.throws(
    () => normalizeManualItem({
      type: 'Jodi',
      number: '04',
      amount: 10,
    }, 0, 'Close'),
    /Jodi is not allowed in Close session/,
  );

  assert.throws(
    () => normalizeManualItem({
      type: 'Full Sangam',
      number: '118-128',
      amount: 10,
    }, 0, 'Close'),
    /Sangam is not allowed in Close session/,
  );

  assert.throws(
    () => normalizeManualItem({
      type: 'Full Sangam',
      number: '118-128 bz',
      amount: 1,
    }, 0, 'Close'),
    /BZ is not allowed in Close session/,
  );
});

test('Close session rejects auto Jodi and Sangam entries', () => {
  const config = standardGameConfigPayload();

  assert.throws(
    () => normalizeAutoItem({
      mode: 'AUTO',
      betType: 'JODI',
      number: '04',
      amount: 10,
    }, config, 0, undefined, 'Close'),
    /Jodi is not allowed in Close session/,
  );

  assert.throws(
    () => normalizeAutoItem({
      mode: 'AUTO',
      betType: 'FULL_SANGAM',
      betSubtype: '01',
      number: '118-128',
      amount: 10,
    }, config, 0, undefined, 'Close'),
    /Sangam is not allowed in Close session/,
  );
});

test('stale stored standard config uses current Panna defaults at runtime', () => {
  const staleConfig = {
    ...standardGameConfigPayload(),
    code: 'STANDARD_GAME_CONFIG',
    panna: {
      enabled: true,
      backendType: 'Patti',
      masterNumberSetCode: 'STANDARD_220_PANNA',
      subtypes: {
        sp: {
          enabled: false,
          allowedNumbers: [],
          missingRule: 'Business rule not currently defined. Supply SP/DP/TP membership before enabling this subtype.',
        },
        dp: {
          enabled: false,
          allowedNumbers: [],
        },
        tp: {
          enabled: false,
          allowedNumbers: [],
        },
      },
    },
  };
  const { payload } = standardPannaNumberSetPayload();
  const serialized = serializeGameConfig(staleConfig, payload);
  const panna = serialized.autoTypes.find((type) => type.id === 'panna');
  const sp = serialized.autoTypes.find((type) => type.id === 'sp');
  const cp = serialized.autoTypes.find((type) => type.id === 'cp');
  const mp = serialized.autoTypes.find((type) => type.id === 'mp');

  assert.deepEqual(panna.subtypes.map((subtype) => subtype.id), ['pana']);
  assert.equal(panna.subtypes.length, 1);
  assert.equal(sp.enabled, true);
  assert.equal(sp.options.length, 120);
  assert.equal(sp.missingRule, null);
  assert.equal(cp.label, 'CP');
  assert.equal(mp.label, 'MP');
  assert.equal(cp.enabled, true);
  assert.equal(mp.enabled, true);
  assert.equal(cp.options.length, 220);
  assert.equal(mp.options.length, 220);
  assert.equal(cp.options.find((option) => option.value === '578').column, 10);
  assert.equal(mp.options.find((option) => option.value === '123').column, 6);
  assert.deepEqual(normalizeAutoItem({
    mode: 'AUTO',
    betType: 'PANNA',
    betSubtype: 'SP',
    number: '128',
    amount: 10,
  }, staleConfig, 0), {
    type: 'Patti',
    number: '128',
    amount: 10,
    mode: 'Auto',
    betType: 'PANNA',
    betSubtype: 'SP',
    isJackpot: false,
  });
});

test('standard config validates CP and MP against calculated 220 Pana master', () => {
  const config = standardGameConfigPayload();

  assert.deepEqual(normalizeAutoItem({
    mode: 'AUTO',
    betType: 'PANNA',
    betSubtype: 'CP',
    number: '578',
    amount: 20,
  }, config, 0), {
    type: 'Patti',
    number: '578',
    amount: 20,
    mode: 'Auto',
    betType: 'PANNA',
    betSubtype: 'CP',
    isJackpot: false,
  });

  assert.deepEqual(normalizeAutoItem({
    mode: 'AUTO',
    betType: 'PANNA',
    betSubtype: 'MP',
    number: '123',
    amount: 30,
  }, config, 0), {
    type: 'Patti',
    number: '123',
    amount: 30,
    mode: 'Auto',
    betType: 'PANNA',
    betSubtype: 'MP',
    isJackpot: false,
  });

  assert.throws(
    () => normalizeAutoItem({
      mode: 'AUTO',
      betType: 'PANNA',
      betSubtype: 'CP',
      number: '001',
      amount: 10,
    }, config, 0),
    /not configured/,
  );
});

test('standard config exposes and validates Panna motor subtype entries', () => {
  const config = standardGameConfigPayload();
  const { payload } = standardPannaNumberSetPayload();
  const serialized = serializeGameConfig(config, payload);
  const spMotorType = serialized.autoTypes.find((type) => type.id === 'sp_motor');
    const spMotor = spMotorType.subtypes.find((subtype) => subtype.id === 'sp_motor_1234567890');

  assert.equal(spMotorType.label, 'SP Motor');
    assert.equal(spMotor.label, '1234567890');
  assert.equal(spMotor.options.length, 120);
  assert.equal(spMotor.options.some((option) => option.value === '890'), true);

  assert.deepEqual(normalizeAutoItem({
    mode: 'AUTO',
    betType: 'PANNA',
    betSubtype: 'SP Motor 12345',
    number: '145',
    amount: 10,
  }, config, 0), {
    type: 'Patti',
    number: '145',
    amount: 10,
    mode: 'Auto',
    betType: 'PANNA',
    betSubtype: 'SP_MOTOR_12345',
    isJackpot: false,
  });

  assert.throws(
    () => normalizeAutoItem({
      mode: 'AUTO',
      betType: 'PANNA',
      betSubtype: 'SP Motor 12345',
      number: '128',
      amount: 10,
    }, config, 0),
    /not configured/,
  );
});

test('standard Panna motor number set preserves supplied grouped strings', () => {
  const { payload, analysis } = standardPannaMotorNumberSetPayload();

  assert.equal(payload.code, 'STANDARD_PANNA_MOTORS');
  assert.equal(payload.groups.length, 7);
  assert.equal(analysis.totalSuppliedEntries, 329);
  assert.equal(analysis.uniqueEntries, 120);
  assert.equal(analysis.duplicateValues.length, 84);
  assert.deepEqual(analysis.invalidStringLengths, []);
  assert.deepEqual(
    payload.groups.map((group) => [group.motor, group.numbers.length]),
    [
      ['SP_MOTOR_1234', 4],
      ['SP_MOTOR_12345', 10],
      ['SP_MOTOR_123456', 20],
      ['SP_MOTOR_1234567', 35],
      ['SP_MOTOR_12345678', 56],
      ['SP_MOTOR_123456789', 84],
      ['SP_MOTOR_1234567890', 120],
    ],
  );
  assert.equal(payload.values.find((entry) => entry.value === '890').value, '890');
  assert.equal(typeof payload.values.find((entry) => entry.value === '890').value, 'string');
});
