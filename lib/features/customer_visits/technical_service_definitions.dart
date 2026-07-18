class TechnicalFieldDefinition {
  final String key;
  final String label;
  final String? unit;

  const TechnicalFieldDefinition(this.key, this.label, {this.unit});
}

const technicalIssueCategories = <String>[
  'Mechanical',
  'Electrical',
  'Controller',
  'Motor',
  'Battery',
  'Charger',
  'Software',
  'Communication',
  'Harness',
  'Sensor',
  'Safety',
  'Other',
];

const technicalDiagnosticFields = <TechnicalFieldDefinition>[
  TechnicalFieldDefinition('errorCode', 'Error Code'),
  TechnicalFieldDefinition('ledBlinkPattern', 'LED Blink Pattern'),
  TechnicalFieldDefinition(
    'controllerErrorNumber',
    'Controller Error Number',
  ),
  TechnicalFieldDefinition('motorNoise', 'Motor Noise'),
  TechnicalFieldDefinition(
    'motorTemperature',
    'Motor Temperature',
    unit: 'C',
  ),
  TechnicalFieldDefinition('batteryVoltage', 'Battery Voltage', unit: 'V'),
  TechnicalFieldDefinition('batteryCurrent', 'Battery Current', unit: 'A'),
  TechnicalFieldDefinition('rmsCurrent', 'RMS Current', unit: 'A'),
  TechnicalFieldDefinition('rpm', 'RPM'),
  TechnicalFieldDefinition('speed', 'Speed', unit: 'km/h'),
  TechnicalFieldDefinition('torque', 'Torque', unit: 'Nm'),
  TechnicalFieldDefinition('throttleReading', 'Throttle Reading'),
  TechnicalFieldDefinition('brakeSignal', 'Brake Signal'),
  TechnicalFieldDefinition('hallSensorStatus', 'Hall Sensor Status'),
  TechnicalFieldDefinition('canCommunication', 'CAN Communication'),
  TechnicalFieldDefinition(
    'controllerTemperature',
    'Controller Temperature',
    unit: 'C',
  ),
  TechnicalFieldDefinition('inputVoltage', 'Input Voltage', unit: 'V'),
  TechnicalFieldDefinition('outputVoltage', 'Output Voltage', unit: 'V'),
  TechnicalFieldDefinition('currentDraw', 'Current Draw', unit: 'A'),
  TechnicalFieldDefinition('insulationStatus', 'Insulation Status'),
];

const technicalChecklistDefinitions = <String, String>{
  'visual_inspection': 'Visual Inspection',
  'loose_wiring': 'Loose Wiring',
  'connector_check': 'Connector Check',
  'harness_check': 'Harness Check',
  'motor_mount': 'Motor Mount',
  'controller_mount': 'Controller Mount',
  'battery_connection': 'Battery Connection',
  'brake_check': 'Brake Check',
  'throttle_check': 'Throttle Check',
  'cooling_check': 'Cooling Check',
  'firmware_check': 'Firmware Check',
  'test_ride': 'Test Ride',
  'road_test': 'Road Test',
  'customer_demonstration': 'Customer Demonstration',
};

const technicalChecklistStatuses = <String>[
  'pending',
  'pass',
  'fail',
  'not_applicable',
];

const technicalResolutionStatuses = <String>[
  'pending',
  'solved',
  'temporary_fix',
  'waiting_parts',
  'waiting_customer',
  'need_factory_support',
  'warranty_approval_pending',
  'replacement_required',
  'cancelled',
  'carry_forward',
];

const technicalTimelineEventTypes = <String>[
  'travel_started',
  'reached_area',
  'work_started',
  'break_started',
  'work_resumed',
  'testing',
  'customer_demo',
  'travel_back',
];

const technicalAttachmentTypes = <String>[
  'video',
  'voice_note',
  'document',
];

String technicalValueLabel(String value) {
  final normalized = value.trim().replaceAll('_', ' ');
  if (normalized.isEmpty) return 'Not recorded';
  return normalized
      .split(RegExp(r'\s+'))
      .map(
        (word) => word.isEmpty
            ? word
            : '${word.substring(0, 1).toUpperCase()}${word.substring(1).toLowerCase()}',
      )
      .join(' ');
}

