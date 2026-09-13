const GameConfig = require('../models/GameConfig');
const Market = require('../models/Market');
const NumberSet = require('../models/NumberSet');
const { assertMarketOpen } = require('./marketAvailability.service');
const ApiError = require('../utils/apiError');
const {
  JODI_VALUES,
  SINGLE_VALUES,
  STANDARD_GAME_CONFIG_CODE,
  STANDARD_PANA_GROUPS,
  STANDARD_PANA_VALUES,
  STANDARD_PANNA_MOTOR_GROUPS,
  STANDARD_PANNA_MOTOR_NUMBER_SET_CODE,
  STANDARD_PANNA_MOTOR_VALUES,
  STANDARD_PANNA_NUMBER_SET_CODE,
  STANDARD_PANNA_SUBTYPE_VALUES,
  STANDARD_PANNA_VALUES,
} = require('../constants/gameConfig.constants');

const manualTypes = new Set([
  'Single',
  'Jodi',
  'Patti',
  'Half Sangam',
  'Full Sangam',
]);

const FULL_SANGAM_JODIS = JODI_VALUES.slice(0, 10);
const FULL_SANGAM_DIGITS = Array.from({ length: 10 }, (_, index) => `${index}`);
const FULL_SANGAM_COLUMN_COUNT = 10;
const AMOUNT_PATTERN = /^\d+(?:\.\d{1,2})?$/;
const COMMON_MULTIPLIER = 36;
const FAMILY_DIGIT_PAIRS = {
  0: '5',
  1: '6',
  2: '7',
  3: '8',
  4: '9',
  5: '0',
  6: '1',
  7: '2',
  8: '3',
  9: '4',
};

function compactCode(value) {
  return `${value || ''}`.trim().toUpperCase().replace(/[^A-Z0-9]/g, '_');
}

function normalizeSession(value) {
  const compact = `${value || ''}`.trim().toLowerCase();
  if (compact === 'open') return 'Open';
  if (compact === 'close') return 'Close';
  throw ApiError.badRequest('Session must be Open or Close');
}

function effectiveItemSession(receiptSession, item) {
  const override = `${item.sessionOverride || ''}`.trim().toLowerCase();
  return receiptSession === 'Open' && override === 'close' ? 'Close' : receiptSession;
}

function numberSetEntries(values) {
  return values.map((entry) => {
    if (typeof entry === 'string') return { value: entry };
    return {
      value: `${entry.value}`,
      ank: entry.ank === undefined ? undefined : `${entry.ank}`,
      pannaType: entry.pannaType === undefined ? undefined : `${entry.pannaType}`,
      motor: entry.motor === undefined ? undefined : `${entry.motor}`,
      column: entry.column,
    };
  });
}

function numberSetGroups(groups) {
  return groups.map((group) => ({
    ank: group.ank === undefined ? undefined : `${group.ank}`,
    label: group.label === undefined ? undefined : `${group.label}`,
    pannaType: group.pannaType === undefined ? undefined : `${group.pannaType}`,
    motor: group.motor === undefined ? undefined : `${group.motor}`,
    numbers: (group.numbers || [...(group.sp || []), ...(group.dp || []), ...(group.tp || [])])
      .map((value) => `${value}`),
    sp: (group.sp || []).map((value) => `${value}`),
    dp: (group.dp || []).map((value) => `${value}`),
    tp: (group.tp || []).map((value) => `${value}`),
  }));
}

function analyzeNumberSetEntries(entries, expectedLength = 3) {
  const counts = new Map();
  const columnsByValue = new Map();
  const invalidStringLengths = [];

  entries.forEach((entry, index) => {
    const value = typeof entry === 'string' ? entry : `${entry.value}`;
    const column = typeof entry === 'string' ? undefined : entry.column;
    counts.set(value, (counts.get(value) || 0) + 1);
    if (!columnsByValue.has(value)) columnsByValue.set(value, new Set());
    if (column !== undefined) columnsByValue.get(value).add(column);
    if (typeof value !== 'string' || value.length !== expectedLength) {
      invalidStringLengths.push({ index, value, length: value.length });
    }
  });

  const duplicateValues = [];
  for (const [value, count] of counts.entries()) {
    if (count > 1) {
      duplicateValues.push({
        value,
        count,
        columns: Array.from(columnsByValue.get(value) || []).sort((a, b) => a - b),
      });
    }
  }

  return {
    totalSuppliedEntries: entries.length,
    uniqueEntries: counts.size,
    duplicateValues,
    duplicatedColumns: duplicateValues.filter((entry) => entry.columns.length > 1),
    invalidStringLengths,
  };
}

function calculatePanaDigit(value) {
  const text = `${value}`;
  if (!/^\d{3}$/.test(text)) return null;
  const sum = text
    .split('')
    .reduce((total, digit) => total + Number(digit), 0);
  return `${sum % 10}`;
}

function normalizePanaGroups(source) {
  const groups = source?.groups?.length ? source.groups : STANDARD_PANA_GROUPS;
  return groups.map((group) => ({
    ank: `${group.ank}`,
    numbers: (group.numbers || []).map((value) => `${value}`),
  }));
}

function analyzePanaMasterGroups(groups) {
  const counts = new Map();
  const invalidStringLengths = [];
  const wrongDigitAssignments = [];
  const groupsByDigit = new Map(
    FULL_SANGAM_DIGITS.map((digit) => [digit, []]),
  );

  groups.forEach((group) => {
    const configuredDigit = `${group.ank}`;
    for (const rawValue of group.numbers || []) {
      const value = `${rawValue}`;
      counts.set(value, (counts.get(value) || 0) + 1);

      if (value.length !== 3) {
        invalidStringLengths.push({
          value,
          configuredDigit,
          length: value.length,
        });
      }

      const calculatedDigit = calculatePanaDigit(value);
      if (calculatedDigit !== configuredDigit) {
        wrongDigitAssignments.push({
          value,
          configuredDigit,
          calculatedDigit,
        });
      }

      if (!groupsByDigit.has(configuredDigit)) {
        groupsByDigit.set(configuredDigit, []);
      }
      groupsByDigit.get(configuredDigit).push(value);
    }
  });

  const duplicateValues = [];
  for (const [value, count] of counts.entries()) {
    if (count > 1) duplicateValues.push({ value, count });
  }
  const countsByDigit = Object.fromEntries(
    FULL_SANGAM_DIGITS.map((digit) => [
      digit,
      groupsByDigit.get(digit)?.length || 0,
    ]),
  );
  const invalidDigitCounts = FULL_SANGAM_DIGITS.flatMap((digit) =>
    countsByDigit[digit] !== 22 ? [{ digit, count: countsByDigit[digit] }] : [],
  );

  return {
    totalMasterPanas: [...counts.values()].reduce((total, count) => total + count, 0),
    uniqueMasterPanas: counts.size,
    countsByDigit,
    duplicateValues,
    invalidStringLengths,
    wrongDigitAssignments,
    invalidDigitCounts,
  };
}

function analyzeStandardPanaMaster(source) {
  return analyzePanaMasterGroups(normalizePanaGroups(source));
}

function assertValidStandardPanaMaster(source) {
  const analysis = analyzeStandardPanaMaster(source);
  if (
    analysis.totalMasterPanas !== 220 ||
    analysis.uniqueMasterPanas !== 220 ||
    analysis.duplicateValues.length ||
    analysis.invalidStringLengths.length ||
    analysis.wrongDigitAssignments.length ||
    analysis.invalidDigitCounts.length
  ) {
    throw ApiError.badRequest('Standard Pana master data is invalid for Full Sangam generation');
  }
  return analysis;
}

function getPanasForDigit(digit, source) {
  const groups = normalizePanaGroups(source);
  assertValidStandardPanaMaster({ groups });
  const normalizedDigit = `${digit}`.trim();
  const group = groups.find(
    (entry) => `${entry.ank}` === normalizedDigit,
  );
  if (!group) {
    throw ApiError.badRequest(`Pana digit ${normalizedDigit} is not configured`);
  }
  return group.numbers.map((value) => `${value}`);
}

function generateFullSangam(openDigit, closeDigit, source) {
  const open = `${openDigit}`.trim();
  const close = `${closeDigit}`.trim();
  const openPanas = getPanasForDigit(open, source);
  const closePanas = getPanasForDigit(close, source);
  const jodi = `${open}${close}`;

  return openPanas.flatMap((openPana) =>
    closePanas.map((closePana, closeIndex) => ({
      jodi,
      openPana,
      closePana,
      value: `${openPana}-${closePana}`,
      column: (closeIndex % FULL_SANGAM_COLUMN_COUNT) + 1,
    })),
  );
}

function fullSangamRules(source) {
  const analysis = assertValidStandardPanaMaster(source);
  const combinationsPerJodi = 22 * 22;
  return {
    generatedFrom: STANDARD_PANNA_NUMBER_SET_CODE,
    jodis: FULL_SANGAM_JODIS,
    combinationsPerJodi,
    totalGeneratedForConfiguredJodis: combinationsPerJodi * FULL_SANGAM_JODIS.length,
    masterPanas: analysis.totalMasterPanas,
    panasPerDigit: analysis.countsByDigit,
  };
}

function standardFullSangamSubtypes(source) {
  return FULL_SANGAM_JODIS.map((jodi) => ({
    id: jodi,
    label: jodi,
    enabled: true,
    allowedLength: 7,
    values: [],
    options: generateFullSangam(jodi[0], jodi[1], source).map((entry) => ({
      value: entry.value,
      column: entry.column,
    })),
    missingRule: null,
    rules: {
      generated: true,
      jodi,
      openDigit: jodi[0],
      closeDigit: jodi[1],
      count: 484,
    },
  }));
}

function standardGameConfigPayload() {
  const missingSangamRule =
    'Business rule not currently defined. Supply structured Sangam fields/rules before enabling this type.';

  return {
    code: STANDARD_GAME_CONFIG_CODE,
    label: 'Standard Game Configuration',
    isActive: true,
    single: {
      enabled: true,
      backendType: 'Single',
      allowedLength: 1,
      values: SINGLE_VALUES,
    },
    jodi: {
      enabled: true,
      backendType: 'Jodi',
      allowedLength: 2,
      values: JODI_VALUES,
    },
    panna: {
      enabled: true,
      backendType: 'Patti',
      masterNumberSetCode: STANDARD_PANNA_NUMBER_SET_CODE,
      subtypes: {
        pana: {
          enabled: true,
          allowedNumbers: STANDARD_PANNA_SUBTYPE_VALUES.pana,
        },
        sp: {
          enabled: true,
          allowedNumbers: STANDARD_PANNA_SUBTYPE_VALUES.sp,
        },
        dp: {
          enabled: true,
          allowedNumbers: STANDARD_PANNA_SUBTYPE_VALUES.dp,
        },
        tp: {
          enabled: true,
          allowedNumbers: STANDARD_PANNA_SUBTYPE_VALUES.tp,
        },
        cp: {
          enabled: true,
          allowedNumbers: STANDARD_PANNA_SUBTYPE_VALUES.pana,
        },
        mp: {
          enabled: true,
          allowedNumbers: STANDARD_PANNA_SUBTYPE_VALUES.pana,
        },
      },
    },
    halfSangam: {
      enabled: false,
      backendType: 'Half Sangam',
      values: [],
      missingRule: missingSangamRule,
      rules: {},
    },
    fullSangam: {
      enabled: true,
      backendType: 'Full Sangam',
      allowedLength: 7,
      values: [],
      missingRule: null,
      rules: fullSangamRules(),
    },
  };
}

function gameConfigForUse(gameConfig) {
  const config = gameConfig?.toObject ? gameConfig.toObject() : gameConfig;
  if (!config || config.code !== STANDARD_GAME_CONFIG_CODE) return config;

  const standard = standardGameConfigPayload();
  return {
    ...config,
    single: standard.single,
    jodi: standard.jodi,
    panna: standard.panna,
    halfSangam: standard.halfSangam,
    fullSangam: standard.fullSangam,
  };
}

function standardPannaNumberSetPayload() {
  const entries = numberSetEntries(STANDARD_PANA_VALUES);
  const groups = numberSetGroups(STANDARD_PANA_GROUPS);
  const analysis = analyzeNumberSetEntries(entries, 3);
  const masterAnalysis = assertValidStandardPanaMaster({ groups });

  if (analysis.invalidStringLengths.length) {
    throw ApiError.badRequest('Standard Panna number set contains invalid number lengths');
  }

  return {
    payload: {
      code: STANDARD_PANNA_NUMBER_SET_CODE,
      label: 'Standard 220 Panna Number Set',
      numberLength: 3,
      values: entries,
      groups,
    },
    analysis: {
      ...analysis,
      master: masterAnalysis,
    },
  };
}

function standardPannaMotorNumberSetPayload() {
  const entries = numberSetEntries(STANDARD_PANNA_MOTOR_VALUES);
  const groups = numberSetGroups(STANDARD_PANNA_MOTOR_GROUPS);
  const analysis = analyzeNumberSetEntries(entries, 3);

  if (analysis.invalidStringLengths.length) {
    throw ApiError.badRequest('Standard Panna motor number set contains invalid number lengths');
  }

  return {
    payload: {
      code: STANDARD_PANNA_MOTOR_NUMBER_SET_CODE,
      label: 'Standard Panna Motor Number Set',
      numberLength: 3,
      values: entries,
      groups,
    },
    analysis,
  };
}

async function upsertStandardPannaNumberSet() {
  const { payload, analysis } = standardPannaNumberSetPayload();

  const numberSet = await NumberSet.findOneAndUpdate(
    { code: STANDARD_PANNA_NUMBER_SET_CODE },
    payload,
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );

  return { numberSet, analysis };
}

async function upsertStandardPannaMotorNumberSet() {
  const { payload, analysis } = standardPannaMotorNumberSetPayload();

  const numberSet = await NumberSet.findOneAndUpdate(
    { code: STANDARD_PANNA_MOTOR_NUMBER_SET_CODE },
    payload,
    { new: true, upsert: true, setDefaultsOnInsert: true },
  );

  return { numberSet, analysis };
}

async function ensureStandardGameConfigUsesPannaNumberSet() {
  let gameConfig = await GameConfig.findOne({ code: STANDARD_GAME_CONFIG_CODE });

  if (!gameConfig) {
    gameConfig = await GameConfig.create(standardGameConfigPayload());
    return gameConfig;
  }

  gameConfig = await GameConfig.findOneAndUpdate(
    { code: STANDARD_GAME_CONFIG_CODE },
    {
      $set: {
        panna: standardGameConfigPayload().panna,
      },
    },
    { new: true },
  );

  return gameConfig;
}

async function upsertStandardPannaNumberSetAndLinkConfig() {
  const [{ numberSet, analysis }, gameConfig] = await Promise.all([
    upsertStandardPannaNumberSet(),
    ensureStandardGameConfigUsesPannaNumberSet(),
  ]);

  return { gameConfig, numberSet, analysis };
}

async function upsertStandardGameConfig() {
  const [
    { numberSet, analysis },
    { numberSet: motorNumberSet, analysis: motorAnalysis },
    gameConfig,
    marketResult,
  ] = await Promise.all([
    upsertStandardPannaNumberSet(),
    upsertStandardPannaMotorNumberSet(),
    GameConfig.findOneAndUpdate(
      { code: STANDARD_GAME_CONFIG_CODE },
      standardGameConfigPayload(),
      { new: true, upsert: true, setDefaultsOnInsert: true },
    ),
    Market.updateMany(
      { isActive: true },
      { $set: { gameConfigCode: STANDARD_GAME_CONFIG_CODE } },
    ),
  ]);

  return {
    gameConfig,
    numberSet,
    motorNumberSet,
    analysis,
    motorAnalysis,
    assignedMarkets: marketResult.modifiedCount ?? marketResult.nModified ?? 0,
    matchedMarkets: marketResult.matchedCount ?? marketResult.n ?? 0,
  };
}

async function loadConfigForMarket(marketId, user) {
  const market = await Market.findById(marketId);
  if (!market) throw ApiError.notFound('Market not found');
  if (market.isDeleted) throw ApiError.notFound('Market not found');
  if (!market.isActive) throw ApiError.badRequest('Market is inactive');
  const assignedMarkets = user?.assignedMarkets || [];
  if (
    user?.role !== 'admin' &&
    assignedMarkets.length > 0 &&
    !assignedMarkets.some((id) => id.toString() === market._id.toString())
  ) {
    throw ApiError.forbidden('Market is not assigned to this operator');
  }

  const code = market.gameConfigCode || STANDARD_GAME_CONFIG_CODE;
  const gameConfig = await GameConfig.findOne({ code, isActive: true });
  if (!gameConfig) {
    throw ApiError.badRequest(`Game configuration ${code} is not active or does not exist`);
  }

  const numberSetCode = gameConfig.panna?.masterNumberSetCode;
  const numberSet = numberSetCode
    ? await NumberSet.findOne({ code: numberSetCode })
    : null;

  return { market, gameConfig, numberSet };
}

function optionMapFromNumberSet(numberSet) {
  const options = new Map();
  for (const entry of numberSet?.values || []) {
    if (!options.has(entry.value)) options.set(entry.value, []);
    options.get(entry.value).push({ 
      value: entry.value, 
      column: entry.column,
      pannaType: entry.pannaType
    });
  }
  return options;
}

function optionsForValues(values, numberSet) {
  const byValue = optionMapFromNumberSet(numberSet);
  const usedIndexes = new Map();
  return values.map((value) => {
    const numberSetOptions = byValue.get(value);
    if (numberSetOptions?.length) {
      const usedIndex = usedIndexes.get(value) || 0;
      usedIndexes.set(value, usedIndex + 1);
      return numberSetOptions[Math.min(usedIndex, numberSetOptions.length - 1)];
    }
    return { value };
  });
}

function motorSubtypeId(group) {
  return compactCode(group.motor).toLowerCase();
}

function motorSubtypeLabel(group) {
  return compactCode(group.motor).split('_').at(-1);
}

function motorSubtypesFor(pannaType) {
  return STANDARD_PANNA_MOTOR_GROUPS.flatMap((group) =>
    group.pannaType === pannaType
      ? [
          {
            id: motorSubtypeId(group),
            label: motorSubtypeLabel(group),
            enabled: true,
            allowedLength: 3,
            values: group.numbers,
            options: optionsForValues(group.numbers, null),
            missingRule: null,
            pannaType: group.pannaType,
            motor: group.motor,
          },
        ]
      : [],
  );
}

function motorGroupForSubtype(subtype) {
  const normalized = compactCode(subtype).toLowerCase();
  return STANDARD_PANNA_MOTOR_GROUPS.find(
    (group) =>
      motorSubtypeId(group) === normalized ||
      compactCode(group.label).toLowerCase() === normalized,
  );
}

function serializeGameConfig(gameConfig, numberSet) {
  const config = gameConfigForUse(gameConfig);
  const analysis = analyzeNumberSetEntries(numberSet?.values || [], 3);
  const pannaSubtypeLabels = {
    pana: 'Pana',
    sp: 'SP',
    dp: 'DP',
    tp: 'TP',
    cp: 'CP',
    mp: 'MP',
  };
  const panaNumberSet = numberSet?.values?.length
    ? numberSet
    : { values: STANDARD_PANA_VALUES, groups: STANDARD_PANA_GROUPS };
  const pannaSubtypeNumberSet = { values: STANDARD_PANNA_VALUES };
  const pannaSubtypes = ['pana'].map((subtype) => {
    const subtypeConfig = config.panna?.subtypes?.[subtype] || {};
    const subtypeNumberSet = panaNumberSet;
    return {
      id: subtype,
      label: pannaSubtypeLabels[subtype] || subtype.toUpperCase(),
      enabled: subtypeConfig.enabled === true,
      allowedLength: 3,
      values: subtypeConfig.allowedNumbers || [],
      options: optionsForValues(subtypeConfig.allowedNumbers || [], subtypeNumberSet),
      missingRule: subtypeConfig.missingRule || null,
    };
  });
  const spMotorSubtypes = motorSubtypesFor('SP');
  const autoTypes = [
    {
      id: 'single',
      label: 'Single',
      betType: 'SINGLE',
      backendType: config.single?.backendType || 'Single',
      enabled: config.single?.enabled === true,
      requiresSubtype: false,
      allowedLength: config.single?.allowedLength || 1,
      values: config.single?.values || [],
      options: optionsForValues(config.single?.values || [], null),
      missingRule: config.single?.missingRule || null,
    },
    {
      id: 'jodi',
      label: 'Jodi',
      betType: 'JODI',
      backendType: config.jodi?.backendType || 'Jodi',
      enabled: config.jodi?.enabled === true,
      requiresSubtype: false,
      allowedLength: config.jodi?.allowedLength || 2,
      values: config.jodi?.values || [],
      options: optionsForValues(config.jodi?.values || [], null),
      missingRule: config.jodi?.missingRule || null,
    },
    {
      id: 'panna',
      label: 'Panna',
      betType: 'PANNA',
      backendType: config.panna?.backendType || 'Patti',
      enabled: config.panna?.enabled === true,
      requiresSubtype: true,
      allowedLength: 3,
      masterNumberSetCode: config.panna?.masterNumberSetCode || null,
      subtypes: pannaSubtypes,
    },
    {
      id: 'sp',
      label: 'SP',
      betType: 'PANNA',
      backendType: config.panna?.backendType || 'Patti',
      enabled: config.panna?.enabled === true,
      requiresSubtype: false,
      allowedLength: 3,
      masterNumberSetCode: null,
      values: config.panna?.subtypes?.sp?.allowedNumbers || [],
      options: optionsForValues(config.panna?.subtypes?.sp?.allowedNumbers || [], pannaSubtypeNumberSet),
      missingRule: config.panna?.subtypes?.sp?.missingRule || null,
    },
    {
      id: 'dp',
      label: 'DP',
      betType: 'PANNA',
      backendType: config.panna?.backendType || 'Patti',
      enabled: config.panna?.enabled === true,
      requiresSubtype: false,
      allowedLength: 3,
      masterNumberSetCode: null,
      values: config.panna?.subtypes?.dp?.allowedNumbers || [],
      options: optionsForValues(config.panna?.subtypes?.dp?.allowedNumbers || [], pannaSubtypeNumberSet),
      missingRule: config.panna?.subtypes?.dp?.missingRule || null,
    },
    {
      id: 'cp',
      label: 'CP',
      betType: 'PANNA',
      backendType: config.panna?.backendType || 'Patti',
      enabled: config.panna?.enabled === true,
      requiresSubtype: false,
      allowedLength: 3,
      masterNumberSetCode: null,
      values: config.panna?.subtypes?.cp?.allowedNumbers || [],
      options: optionsForValues(config.panna?.subtypes?.cp?.allowedNumbers || [], panaNumberSet),
      missingRule: config.panna?.subtypes?.cp?.missingRule || null,
    },
    {
      id: 'mp',
      label: 'MP',
      betType: 'PANNA',
      backendType: config.panna?.backendType || 'Patti',
      enabled: config.panna?.enabled === true,
      requiresSubtype: false,
      allowedLength: 3,
      masterNumberSetCode: null,
      values: config.panna?.subtypes?.mp?.allowedNumbers || [],
      options: optionsForValues(config.panna?.subtypes?.mp?.allowedNumbers || [], panaNumberSet),
      missingRule: config.panna?.subtypes?.mp?.missingRule || null,
    },
    {
      id: 'sp_motor',
      label: 'SP Motor',
      betType: 'PANNA',
      backendType: config.panna?.backendType || 'Patti',
      enabled: config.panna?.enabled === true,
      requiresSubtype: true,
      allowedLength: 3,
      masterNumberSetCode: STANDARD_PANNA_MOTOR_NUMBER_SET_CODE,
      values: [],
      options: [],
      subtypes: spMotorSubtypes,
      missingRule: null,
    },
    

    {
      id: 'full_sangam',
      label: 'Full Sangam',
      betType: 'FULL_SANGAM',
      backendType: config.fullSangam?.backendType || 'Full Sangam',
      enabled: config.fullSangam?.enabled === true,
      requiresSubtype: true,
      allowedLength: config.fullSangam?.allowedLength || 0,
      values: config.fullSangam?.values || [],
      options: [],
      subtypes:
        config.fullSangam?.enabled === true ? standardFullSangamSubtypes(panaNumberSet) : [],
      missingRule: config.fullSangam?.missingRule || null,
      rules: config.fullSangam?.enabled === true
        ? fullSangamRules(panaNumberSet)
        : (config.fullSangam?.rules || {}),
    },
  ];

  return {
    code: config.code,
    label: config.label,
    autoTypes,
    numberSets: numberSet
      ? [
          {
            code: numberSet.code,
            label: numberSet.label,
            numberLength: numberSet.numberLength,
            totalEntries: numberSet.values.length,
            values: numberSet.values,
            analysis,
          },
        ]
      : [],
    missingBusinessRules: autoTypes
      .flatMap((type) => [
        type.missingRule,
        ...(type.subtypes || []).map((subtype) => subtype.missingRule),
      ])
      .filter(Boolean),
  };
}

function ensureStringNumber(value, index) {
  if (typeof value !== 'string') {
    throw ApiError.badRequest(`Item ${index + 1} number must be submitted as a string`);
  }
  return value.trim();
}

function ensurePositiveAmount(value, index) {
  const rawAmount = `${value ?? ''}`.trim();
  const amount = Number(rawAmount);
  if (!Number.isFinite(amount) || amount <= 0) {
    throw ApiError.badRequest(`Item ${index + 1} amount must be greater than 0`);
  }
  if (!AMOUNT_PATTERN.test(rawAmount)) {
    throw ApiError.badRequest(`Item ${index + 1} amount must use up to 2 decimal places`);
  }
  return amount;
}

function ensureConfiguredValue({ config, values, number, allowedLength, label, index }) {
  if (config?.enabled !== true) {
    throw ApiError.badRequest(config?.missingRule || `Business rule not currently defined for ${label}`);
  }
  if (!new RegExp(`^\\d{${allowedLength}}$`).test(number)) {
    throw ApiError.badRequest(`Item ${index + 1} number format is invalid for ${label}`);
  }
  if (!Array.isArray(values) || values.length === 0) {
    throw ApiError.badRequest(config?.missingRule || `Business rule not currently defined for ${label}`);
  }
  if (!values.includes(number)) {
    throw ApiError.badRequest(`Item ${index + 1} number is not configured for ${label}`);
  }
}

function pannaSubtypeRule(config, subtype) {
  const normalized = compactCode(subtype).toLowerCase();
  const subtypeConfig = config.panna?.subtypes?.[normalized];
  if (subtypeConfig) {
    return {
      config: subtypeConfig,
      values: subtypeConfig.allowedNumbers,
      label: `PANNA ${normalized.toUpperCase()}`,
      outputSubtype: normalized.toUpperCase(),
    };
  }

  const motorGroup = motorGroupForSubtype(subtype);
  if (motorGroup) {
    return {
      config: { enabled: true },
      values: motorGroup.numbers,
      label: `PANNA ${motorGroup.label.toUpperCase()}`,
      outputSubtype: motorGroup.motor,
    };
  }

  return {
    config: undefined,
    values: undefined,
    label: `PANNA ${normalized.toUpperCase()}`,
    outputSubtype: normalized.toUpperCase(),
  };
}

function normalizeFullSangamItem(item, config, number, amount, index, numberSet) {
  if (config.fullSangam?.enabled !== true) {
    throw ApiError.badRequest(
      config.fullSangam?.missingRule || 'Business rule not currently defined for FULL_SANGAM',
    );
  }

  const jodi = `${item.betSubtype || item.jodi || item.components?.jodi || ''}`.trim();
  if (!FULL_SANGAM_JODIS.includes(jodi)) {
    throw ApiError.badRequest(
      `Item ${index + 1} Full Sangam Jodi must be one of ${FULL_SANGAM_JODIS.join(', ')}`,
    );
  }

  if (!/^\d{3}-\d{3}$/.test(number)) {
    throw ApiError.badRequest(`Item ${index + 1} number format is invalid for FULL_SANGAM`);
  }

  const [openPana, closePana] = number.split('-');
  const openDigit = calculatePanaDigit(openPana);
  const closeDigit = calculatePanaDigit(closePana);
  const openPanas = getPanasForDigit(openDigit, numberSet);
  const closePanas = getPanasForDigit(closeDigit, numberSet);

  if (!openPanas.includes(openPana)) {
    throw ApiError.badRequest(`Item ${index + 1} open Pana is not configured for Full Sangam`);
  }
  if (!closePanas.includes(closePana)) {
    throw ApiError.badRequest(`Item ${index + 1} close Pana is not configured for Full Sangam`);
  }

  const expectedJodi = `${openDigit}${closeDigit}`;
  if (jodi !== expectedJodi) {
    throw ApiError.badRequest(
      `Item ${index + 1} Full Sangam Jodi ${jodi} does not match number ${number}; expected ${expectedJodi}`,
    );
  }

  return {
    type: config.fullSangam.backendType || 'Full Sangam',
    number,
    amount,
    mode: 'Auto',
    betType: 'FULL_SANGAM',
    betSubtype: expectedJodi,
    components: {
      jodi: expectedJodi,
      openPana,
      closePana,
    },
  };
}

function normalizeJackpotComponents(item, index) {
  const rawEntries = item.components?.jackpotEntries;
  const rawNumbers = item.components?.jackpotNumbers;
  if (rawEntries === undefined && rawNumbers === undefined) return undefined;

  const source = rawEntries ?? rawNumbers;
  if (!Array.isArray(source) || source.length > 10) {
    throw ApiError.badRequest(`Item ${index + 1} jackpot entries are invalid`);
  }

  const jackpotEntries = source.flatMap((entry) => {
    const item =
      entry && typeof entry === 'object' && !Array.isArray(entry)
        ? {
            number: `${entry.number || ''}`.trim(),
            amount: `${entry.amount || ''}`.trim(),
            calculatedAmount: `${entry.calculatedAmount || ''}`.trim(),
          }
        : {
            number: `${entry}`.trim(),
            amount: '',
            calculatedAmount: '',
          };
    return item.number || item.amount ? [item] : [];
  });

  if (jackpotEntries.some((entry) => !/^\d$/.test(entry.number))) {
    throw ApiError.badRequest(`Item ${index + 1} jackpot numbers must be single digits`);
  }
  if (jackpotEntries.some((entry) => entry.amount && !AMOUNT_PATTERN.test(entry.amount))) {
    throw ApiError.badRequest(`Item ${index + 1} jackpot amounts must be numeric`);
  }
  if (
    jackpotEntries.some(
      (entry) => entry.calculatedAmount && !AMOUNT_PATTERN.test(entry.calculatedAmount),
    )
  ) {
    throw ApiError.badRequest(`Item ${index + 1} jackpot calculated amounts must be numeric`);
  }

  return jackpotEntries.length
    ? {
        jackpotEntries: jackpotEntries.map((entry) => ({
          number: entry.number,
          amount: entry.amount,
          ...(entry.calculatedAmount ? { calculatedAmount: entry.calculatedAmount } : {}),
        })),
      }
    : undefined;
}

function normalizeDisplayAmountComponent(item, index) {
  const value = item.components?.displayAmount;
  if (value === undefined) return undefined;
  const displayAmount = `${value}`.trim();
  if (!AMOUNT_PATTERN.test(displayAmount)) {
    throw ApiError.badRequest(`Item ${index + 1} display amount must be numeric`);
  }
  return { displayAmount };
}

function combineComponents(...parts) {
  const components = Object.assign({}, ...parts.filter(Boolean));
  return Object.keys(components).length ? components : undefined;
}

function truthyFlag(value) {
  if (value === true) return true;
  const text = `${value || ''}`.trim().toLowerCase();
  return text === 'true' || text === '1' || text === 'yes' || text === 'bz';
}

function hasJackpotInput(item) {
  if (item.isJackpot === true) return true;
  const components =
    item.components && typeof item.components === 'object' && !Array.isArray(item.components)
      ? item.components
      : {};
  const entries = components.jackpotEntries ?? components.jackpotNumbers;
  return Array.isArray(entries) && entries.some((entry) => {
    if (entry && typeof entry === 'object' && !Array.isArray(entry)) {
      return `${entry.number || ''}`.trim() || `${entry.amount || ''}`.trim();
    }
    return `${entry || ''}`.trim();
  });
}

function hasBazarFlag(item) {
  const components =
    item.components && typeof item.components === 'object' && !Array.isArray(item.components)
      ? item.components
      : {};
  return (
    truthyFlag(components.bazar) ||
    truthyFlag(components.bazarSangam) ||
    truthyFlag(components.isBazar)
  );
}

function isSangamNumber(number) {
  return `${number}`.trim().replace(/[->]/g, '*').includes('*');
}

function isJodiNumber(number) {
  return /^\d{2}$/.test(`${number}`.trim());
}

function hasRepeatedDigit(value) {
  const digits = `${value || ''}`.replace(/\D/g, '');
  return new Set(digits.split('')).size !== digits.length;
}

function isManualMotorPanaInput(item, number) {
  const betType = compactCode(item.betType || item.type);
  const betSubtype = compactCode(item.betSubtype || item.subtype || '');
  return (
    betType === 'SP_MOTOR' ||
    betType === 'MOTOR' ||
    betSubtype === 'SP_MOTOR' ||
    betSubtype === 'MOTOR' ||
    betSubtype.startsWith('SP_MOTOR_') ||
    /^\d{4,}$/.test(`${number}`.trim())
  );
}

function assertJodiHasNoJackpot(item, index, isJodi) {
  if (isJodi && hasJackpotInput(item)) {
    throw ApiError.badRequest(`Item ${index + 1} Jackpot is not allowed for Jodi`);
  }
}

function assertMotorPanaHasUniqueDigits(item, index, number) {
  if (isManualMotorPanaInput(item, number) && hasRepeatedDigit(number)) {
    throw ApiError.badRequest(`Item ${index + 1} MP number cannot contain repeated digits`);
  }
}

function assertCloseManualItemAllowed(item, index, number, bazarMatch, isCpJodi = false) {
  if (hasJackpotInput(item)) {
    throw ApiError.badRequest(`Item ${index + 1} Jackpot is not allowed in Close session`);
  }
  if (bazarMatch || hasBazarFlag(item)) {
    throw ApiError.badRequest(`Item ${index + 1} BZ is not allowed in Close session`);
  }
  if (!isCpJodi && (item.type === 'Jodi' || isJodiNumber(number))) {
    throw ApiError.badRequest(`Item ${index + 1} Jodi is not allowed in Close session`);
  }
  if (item.type === 'Half Sangam' || item.type === 'Full Sangam' || isSangamNumber(number)) {
    throw ApiError.badRequest(`Item ${index + 1} Sangam is not allowed in Close session`);
  }
}

function assertCloseAutoItemAllowed(item, betType, index) {
  if (hasJackpotInput(item)) {
    throw ApiError.badRequest(`Item ${index + 1} Jackpot is not allowed in Close session`);
  }
  if (hasBazarFlag(item)) {
    throw ApiError.badRequest(`Item ${index + 1} BZ is not allowed in Close session`);
  }
  if (betType === 'JODI') {
    throw ApiError.badRequest(`Item ${index + 1} Jodi is not allowed in Close session`);
  }
  if (betType === 'HALF_SANGAM' || betType === 'FULL_SANGAM') {
    throw ApiError.badRequest(`Item ${index + 1} Sangam is not allowed in Close session`);
  }
}

function normalizeSangamComponents(item, hasBazarPrefix, index, bazarDisplayAmount) {
  const rawComponents =
    item.components && typeof item.components === 'object' && !Array.isArray(item.components)
      ? item.components
      : {};
  const displayAmount =
    normalizeDisplayAmountComponent(item, index) ||
    (hasBazarPrefix ? { displayAmount: `${bazarDisplayAmount}` } : undefined);
  const isBazar =
    hasBazarPrefix ||
    truthyFlag(rawComponents.bazar) ||
    truthyFlag(rawComponents.bazarSangam) ||
    truthyFlag(rawComponents.isBazar);
  return combineComponents(displayAmount, isBazar ? { bazar: true } : undefined);
}

function rawComponentsFor(item) {
  return item.components && typeof item.components === 'object' && !Array.isArray(item.components)
    ? item.components
    : {};
}

function hasFamilyFlag(item) {
  const rawComponents = rawComponentsFor(item);
  return truthyFlag(rawComponents.family) || truthyFlag(rawComponents.isFamily);
}

function hasCpJodiFlag(item) {
  const rawComponents = rawComponentsFor(item);
  return truthyFlag(rawComponents.cp) || truthyFlag(rawComponents.cpJodi) || truthyFlag(rawComponents.isCp);
}

function hasCommonFlag(item) {
  const rawComponents = rawComponentsFor(item);
  const subtype = compactCode(item.betSubtype || item.subtype || '');
  return (
    truthyFlag(rawComponents.common) ||
    truthyFlag(rawComponents.commonSingle) ||
    truthyFlag(rawComponents.isCommon) ||
    subtype === 'COMMON' ||
    subtype === 'CM'
  );
}

function familyNumberFromInput(value) {
  const text = `${value || ''}`.trim();
  const match = text.match(/^(?:f\s*(\d{2,3})|(\d{2,3})\s*f)$/i);
  return match ? match[1] || match[2] : null;
}

function cpJodiNumberFromInput(value) {
  const text = `${value || ''}`.trim();
  const match = text.match(/^(?:cp\s*(\d{2})|(\d{2})\s*cp)$/i);
  return match ? match[1] || match[2] : null;
}

function commonNumberFromInput(value) {
  const text = `${value || ''}`.trim();
  const match = text.match(/^(?:(?:cm|common)\s*(\d)|(\d)\s*(?:cm|common))$/i);
  return match ? match[1] || match[2] : null;
}

function jackpotCalculatedTotal(components, multiplier) {
  const entries = components?.jackpotEntries || [];
  return entries.reduce((total, entry) => {
    const calculatedAmount = Number(entry.calculatedAmount || 0);
    if (calculatedAmount > 0) return total + calculatedAmount;
    const baseAmount = Number(entry.amount || 0);
    return baseAmount > 0 ? total + baseAmount * multiplier : total;
  }, 0);
}

function jodiDigitWeight(digit) {
  return digit === '0' ? 10 : Number(digit);
}

function isAscendingJodi(number) {
  return jodiDigitWeight(number[0]) <= jodiDigitWeight(number[1]);
}

function familyDigitWeight(digit) {
  return digit === '0' ? 10 : Number(digit);
}

function canonicalFamilyPana(value) {
  return `${value}`
    .split('')
    .sort((left, right) => familyDigitWeight(left) - familyDigitWeight(right))
    .join('');
}

function familyMultiplierFor(number) {
  const value = `${number || ''}`.trim();
  if (!/^\d{2,3}$/.test(value)) return 0;
  if (value.length === 2) {
    const firstDigit = value[0];
    const secondDigit = value[1];
    const sameFamily =
      firstDigit === secondDigit || FAMILY_DIGIT_PAIRS[firstDigit] === secondDigit;
    return sameFamily ? 4 : 8;
  }
  const variants = new Set();
  for (let mask = 0; mask < 8; mask += 1) {
    let mapped = '';
    for (let index = 0; index < value.length; index += 1) {
      const digit = value[index];
      mapped += (mask & (1 << index)) === 0 ? digit : FAMILY_DIGIT_PAIRS[digit];
    }
    variants.add(canonicalFamilyPana(mapped));
  }
  return variants.size;
}

function normalizeManualItem(item, index, session = 'Open') {
  if (!manualTypes.has(item.type)) {
    throw ApiError.badRequest(`Item ${index + 1} type is invalid`);
  }
  const enteredAmount = ensurePositiveAmount(item.amount, index);
  let amount = enteredAmount;
  const rawNumber = `${item.number || ''}`.trim();
  const isSangam = item.type === 'Half Sangam' || item.type === 'Full Sangam';
  const markerFamilyNumber = familyNumberFromInput(rawNumber);
  const markerCpJodiNumber = cpJodiNumberFromInput(rawNumber);
  const markerCommonNumber = commonNumberFromInput(rawNumber);
  const hasCpMarker = /cp/i.test(rawNumber);
  const hasCommonMarker = /(?:cm|common)/i.test(rawNumber);
  const isFamily = markerFamilyNumber !== null || hasFamilyFlag(item);
  const isCpJodi = markerCpJodiNumber !== null || hasCpMarker || hasCpJodiFlag(item);
  const isCommon = markerCommonNumber !== null || hasCommonMarker || hasCommonFlag(item);
  if (isFamily && item.type !== 'Patti' && item.type !== 'Jodi') {
    throw ApiError.badRequest(`Item ${index + 1} Family can be used only with Patti or Jodi entries`);
  }
  if (isCpJodi && item.type !== 'Jodi') {
    throw ApiError.badRequest(`Item ${index + 1} CP can be used only with Jodi entries`);
  }
  if (isCommon && item.type !== 'Single') {
    throw ApiError.badRequest(`Item ${index + 1} Common can be used only with Single entries`);
  }
  const bazarMatch =
    rawNumber.match(/^(.+?)\s*bz$/i) || rawNumber.match(/^bz\s*(.+)$/i);
  if (bazarMatch && !isSangam) {
    throw ApiError.badRequest(`Item ${index + 1} BZ can be used only with Sangam`);
  }
  const number = markerFamilyNumber || markerCpJodiNumber || markerCommonNumber || (bazarMatch ? bazarMatch[1].trim() : rawNumber);
  if (!number) throw ApiError.badRequest(`Item ${index + 1} number is required`);
  const isJodi = item.type === 'Jodi' || isJodiNumber(number);
  if (session === 'Close') {
    assertCloseManualItemAllowed(item, index, number, bazarMatch, isCpJodi);
  }
  assertJodiHasNoJackpot(item, index, isJodi);
  assertMotorPanaHasUniqueDigits(item, index, number);
  if (isFamily) {
    if (!/^\d{2,3}$/.test(number)) {
      throw ApiError.badRequest(`Item ${index + 1} Family number must be 2 or 3 digits`);
    }
    const display = normalizeDisplayAmountComponent(item, index);
    const jackpotComponents = normalizeJackpotComponents(item, index);
    const baseAmount = display ? Number(display.displayAmount) : amount;
    const multiplier = familyMultiplierFor(number);
    const isJodiFamily = number.length === 2;
    amount = baseAmount * multiplier + jackpotCalculatedTotal(jackpotComponents, multiplier);
    const components = combineComponents(
      { displayAmount: display?.displayAmount ?? `${baseAmount}` },
      { family: true, familyMultiplier: multiplier },
      jackpotComponents,
    );
    return {
      type: isJodiFamily ? 'Jodi' : 'Patti',
      number,
      amount,
      mode: 'Manual',
      betType: isJodiFamily ? 'JODI' : 'PANNA',
      betSubtype: 'FAMILY',
      isJackpot: !!item.isJackpot || Boolean(jackpotComponents),
      ...(components ? { components } : {}),
    };
  }
  if (isCpJodi) {
    if (!/^\d{2}$/.test(number)) {
      throw ApiError.badRequest(`Item ${index + 1} CP number must be 2 digits`);
    }
    if (!isAscendingJodi(number)) {
      throw ApiError.badRequest(`Item ${index + 1} CP number must be ascending`);
    }
    const display = normalizeDisplayAmountComponent(item, index);
    const baseAmount = display ? Number(display.displayAmount) : amount;
    amount = baseAmount * 10;
    const components = combineComponents(
      { displayAmount: display?.displayAmount ?? `${baseAmount}` },
      { cp: true, cpMultiplier: 10 },
    );
    return {
      type: 'Jodi',
      number,
      amount,
      mode: 'Manual',
      betType: 'JODI',
      betSubtype: 'CP',
      isJackpot: false,
      ...(components ? { components } : {}),
    };
  }
  if (isCommon) {
    if (!/^\d$/.test(number)) {
      throw ApiError.badRequest(`Item ${index + 1} Common number must be single digit`);
    }
    const display = normalizeDisplayAmountComponent(item, index);
    const baseAmount = display ? Number(display.displayAmount) : amount;
    const jackpotComponents = normalizeJackpotComponents(item, index);
    amount = baseAmount * COMMON_MULTIPLIER + jackpotCalculatedTotal(jackpotComponents, COMMON_MULTIPLIER);
    const components = combineComponents(
      { displayAmount: display?.displayAmount ?? `${baseAmount}` },
      { common: true, commonMultiplier: COMMON_MULTIPLIER },
      jackpotComponents,
    );
    return {
      type: 'Single',
      number,
      amount,
      mode: 'Manual',
      betType: 'SINGLE',
      betSubtype: 'COMMON',
      isJackpot: !!item.isJackpot,
      ...(components ? { components } : {}),
    };
  }
  if (bazarMatch) amount *= 10;
  const components = isSangam
    ? normalizeSangamComponents(item, !!bazarMatch, index, enteredAmount)
    : combineComponents(
        normalizeDisplayAmountComponent(item, index),
        normalizeJackpotComponents(item, index),
      );
  return {
    type: item.type,
    number,
    amount,
    mode: 'Manual',
    ...(item.betSubtype ? { betSubtype: item.betSubtype } : {}),
    isJackpot: isSangam || isJodi ? false : !!item.isJackpot,
    ...(components ? { components } : {}),
  };
}

function normalizeAutoItem(item, gameConfig, index, numberSet, session = 'Open') {
  const config = gameConfigForUse(gameConfig);
  const betType = compactCode(item.betType || item.type);
  const betSubtype = item.betSubtype ? compactCode(item.betSubtype).toLowerCase() : undefined;
  const number = ensureStringNumber(item.number, index);
  const amount = ensurePositiveAmount(item.amount, index);
  if (session === 'Close') {
    assertCloseAutoItemAllowed(item, betType, index);
  }

  if (betType === 'SINGLE') {
    ensureConfiguredValue({
      config: config.single,
      values: config.single?.values,
      number,
      allowedLength: config.single?.allowedLength || 1,
      label: 'SINGLE',
      index,
    });
    return {
      type: config.single.backendType || 'Single',
      number,
      amount,
      mode: 'Auto',
      betType: 'SINGLE',
      isJackpot: !!item.isJackpot,
    };
  }

  if (betType === 'JODI') {
    assertJodiHasNoJackpot(item, index, true);
    ensureConfiguredValue({
      config: config.jodi,
      values: config.jodi?.values,
      number,
      allowedLength: config.jodi?.allowedLength || 2,
      label: 'JODI',
      index,
    });
    return {
      type: config.jodi.backendType || 'Jodi',
      number,
      amount,
      mode: 'Auto',
      betType: 'JODI',
      isJackpot: false,
    };
  }

  if (betType === 'PANNA' || betType === 'PATTI') {
    if (!betSubtype) {
      throw ApiError.badRequest(`Item ${index + 1} Panna subtype is required`);
    }
    const subtypeRule = pannaSubtypeRule(config, betSubtype);
    ensureConfiguredValue({
      config: subtypeRule.config,
      values: subtypeRule.values,
      number,
      allowedLength: 3,
      label: subtypeRule.label,
      index,
    });
    return {
      type: config.panna.backendType || 'Patti',
      number,
      amount,
      mode: 'Auto',
      betType: 'PANNA',
      betSubtype: subtypeRule.outputSubtype,
      isJackpot: !!item.isJackpot,
    };
  }

  if (betType === 'HALF_SANGAM' || betType === 'HALF_SANGAM'.replace('_', ' ')) {
    throw ApiError.badRequest(
      config.halfSangam?.missingRule || 'Business rule not currently defined for HALF_SANGAM',
    );
  }

  if (betType === 'FULL_SANGAM' || betType === 'FULL_SANGAM'.replace('_', ' ')) {
    return normalizeFullSangamItem(item, config, number, amount, index, numberSet);
  }

  throw ApiError.badRequest(`Item ${index + 1} bet type is not configured`);
}

function receiptItemHasJackpot(item) {
  const components =
    item.components && typeof item.components === 'object' && !Array.isArray(item.components)
      ? item.components
      : {};
  return (
    item.isJackpot === true ||
    (Array.isArray(components.jackpotEntries) && components.jackpotEntries.length > 0)
  );
}

function assertNoCloseSessionJackpots(session, items) {
  if (session !== 'Close') return;
  const jackpotIndex = items.findIndex(receiptItemHasJackpot);
  if (jackpotIndex !== -1) {
    throw ApiError.badRequest(`Item ${jackpotIndex + 1} Jackpot is not allowed in Close session`);
  }
}

async function validateReceiptPayload({ marketId, session, items, user }) {
  if (!marketId || !session || !Array.isArray(items) || items.length === 0) {
    throw ApiError.badRequest('Market, session, and items are required');
  }

  const { market, gameConfig, numberSet } = await loadConfigForMarket(marketId, user);
  assertMarketOpen(market, new Date());

  const normalizedSession = normalizeSession(session);
  const normalizedItems = items.map((item, index) => {
    const autoMode = `${item.mode || ''}`.trim().toUpperCase() === 'AUTO' || item.betType;
    const itemSession = effectiveItemSession(normalizedSession, item);
    const normalizedItem = autoMode
      ? normalizeAutoItem(item, gameConfig, index, numberSet, itemSession)
      : normalizeManualItem(item, index, itemSession);
    return itemSession === 'Close' && normalizedSession === 'Open'
      ? { ...normalizedItem, sessionOverride: 'Close' }
      : normalizedItem;
  });
  assertNoCloseSessionJackpots(normalizedSession, normalizedItems);

  return { market, session: normalizedSession, items: normalizedItems, gameConfig };
}

module.exports = {
  analyzeNumberSetEntries,
  analyzeStandardPanaMaster,
  generateFullSangam,
  getPanasForDigit,
  ensureStandardGameConfigUsesPannaNumberSet,
  loadConfigForMarket,
  assertNoCloseSessionJackpots,
  normalizeAutoItem,
  normalizeManualItem,
  serializeGameConfig,
  standardGameConfigPayload,
  standardPannaMotorNumberSetPayload,
  standardPannaNumberSetPayload,
  upsertStandardGameConfig,
  upsertStandardPannaMotorNumberSet,
  upsertStandardPannaNumberSet,
  upsertStandardPannaNumberSetAndLinkConfig,
  validateReceiptPayload,
};
