enum ContractFieldKind { text, number, date, multiline }

class ContractTemplateField {
  const ContractTemplateField({
    required this.key,
    required this.label,
    required this.placeholder,
    this.kind = ContractFieldKind.text,
    this.required = false,
  });

  final String key;
  final String label;
  final String placeholder;
  final ContractFieldKind kind;
  final bool required;
}

class ContractTemplate {
  const ContractTemplate({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.forRole,
    required this.content,
    this.fields = const [],
  });

  final String id;
  final String name;
  final String description;
  final String category;
  final String forRole;
  final String content;
  final List<ContractTemplateField> fields;

  String applyValues(Map<String, String> values) {
    var result = content;
    for (final entry in values.entries) {
      final value = entry.value.trim();
      if (value.isNotEmpty) {
        result = result.replaceAll('{{${entry.key}}}', value);
      }
    }
    return result;
  }
}

const _commonPartyFields = <ContractTemplateField>[
  ContractTemplateField(
    key: 'effective_date',
    label: 'Effective date',
    placeholder: 'YYYY-MM-DD',
    kind: ContractFieldKind.date,
    required: true,
  ),
  ContractTemplateField(
    key: 'landlord_name',
    label: 'Owner / first party',
    placeholder: 'Full legal name',
    required: true,
  ),
  ContractTemplateField(
    key: 'tenant_name',
    label: 'Client / second party',
    placeholder: 'Full legal name',
    required: true,
  ),
];

const _leaseFields = <ContractTemplateField>[
  ..._commonPartyFields,
  ContractTemplateField(
    key: 'property_address',
    label: 'Property address',
    placeholder: 'Full address',
    required: true,
  ),
  ContractTemplateField(
    key: 'monthly_rent',
    label: 'Monthly rent',
    placeholder: 'e.g. USD 2,500',
    kind: ContractFieldKind.number,
  ),
  ContractTemplateField(
    key: 'security_deposit',
    label: 'Security deposit',
    placeholder: 'e.g. USD 2,500',
    kind: ContractFieldKind.number,
  ),
  ContractTemplateField(
    key: 'lease_term',
    label: 'Lease term',
    placeholder: 'e.g. 12 months',
  ),
];

const _saleFields = <ContractTemplateField>[
  ..._commonPartyFields,
  ContractTemplateField(
    key: 'property_address',
    label: 'Property / asset description',
    placeholder: 'Address or asset description',
  ),
  ContractTemplateField(
    key: 'purchase_price',
    label: 'Purchase price',
    placeholder: 'e.g. USD 250,000',
    kind: ContractFieldKind.number,
  ),
  ContractTemplateField(
    key: 'earnest_money',
    label: 'Deposit / earnest money',
    placeholder: 'e.g. USD 10,000',
    kind: ContractFieldKind.number,
  ),
  ContractTemplateField(
    key: 'closing_date',
    label: 'Closing date',
    placeholder: 'YYYY-MM-DD',
    kind: ContractFieldKind.date,
  ),
];

const _vehicleRentalFields = <ContractTemplateField>[
  ContractTemplateField(
    key: 'effective_date',
    label: 'Agreement date',
    placeholder: 'YYYY-MM-DD',
    kind: ContractFieldKind.date,
  ),
  ContractTemplateField(
    key: 'landlord_name',
    label: 'Owner / rental company',
    placeholder: 'Full legal name',
  ),
  ContractTemplateField(
    key: 'tenant_name',
    label: 'Renter',
    placeholder: 'Full legal name',
  ),
  ContractTemplateField(
    key: 'asset_description',
    label: 'Vehicle / asset',
    placeholder: 'Brand, model, year, serial/VIN',
  ),
  ContractTemplateField(
    key: 'rental_fee',
    label: 'Rental fee',
    placeholder: 'Amount and unit',
    kind: ContractFieldKind.number,
  ),
  ContractTemplateField(
    key: 'security_deposit',
    label: 'Security deposit',
    placeholder: 'Amount',
    kind: ContractFieldKind.number,
  ),
];

const _serviceFields = <ContractTemplateField>[
  ContractTemplateField(
    key: 'effective_date',
    label: 'Agreement date',
    placeholder: 'YYYY-MM-DD',
    kind: ContractFieldKind.date,
  ),
  ContractTemplateField(
    key: 'landlord_name',
    label: 'Service provider',
    placeholder: 'Name / business',
  ),
  ContractTemplateField(
    key: 'tenant_name',
    label: 'Client',
    placeholder: 'Name / business',
  ),
  ContractTemplateField(
    key: 'services',
    label: 'Services',
    placeholder: 'Describe the work',
    kind: ContractFieldKind.multiline,
  ),
  ContractTemplateField(
    key: 'service_fee',
    label: 'Compensation',
    placeholder: 'Amount and payment cadence',
  ),
  ContractTemplateField(
    key: 'service_term',
    label: 'Term / schedule',
    placeholder: 'Dates, days, hours, notice',
  ),
];

const contractTemplates = <ContractTemplate>[
  ContractTemplate(
    id: 'lease-residential-12-month',
    name: 'Residential Lease — 12 Month',
    description:
        'Full residential lease with rent, deposit, utilities, pets, maintenance, termination, notices and signatures.',
    category: 'Lease',
    forRole: 'both',
    fields: _leaseFields,
    content:
        '''RESIDENTIAL LEASE AGREEMENT\nStandard Twelve (12) Month Term\n\nEffective Date: {{effective_date}}\nLANDLORD: {{landlord_name}}\nTENANT: {{tenant_name}}\nPROPERTY: {{property_address}}\n\n1. TERM\nThe tenancy begins on the effective date and continues for {{lease_term}} unless the parties agree otherwise in writing. Any holdover or renewal is subject to local law and written notice requirements.\n\n2. RENT\nMonthly rent is {{monthly_rent}}. The parties will state the due date, accepted payment method, late-fee terms, prorated first-month rent, and any returned-payment fee before signing.\n\n3. SECURITY DEPOSIT\nSecurity deposit: {{security_deposit}}. The deposit may be applied only as permitted by law, including unpaid rent or damage beyond ordinary wear, and must be returned with any required itemization within the legally required period.\n\n4. UTILITIES AND SERVICES\nThe parties must identify who pays electricity, water, gas, internet, trash, HOA/common-area charges, landscaping, cleaning and any other recurring service.\n\n5. USE AND OCCUPANCY\nResidential use only. No illegal activity. Maximum occupants, guest rules, parking, storage, pets, smoking, subletting and short-term rental restrictions must be written into this agreement or an attached addendum.\n\n6. MAINTENANCE AND REPAIRS\nLandlord remains responsible for obligations imposed by applicable habitability law. Tenant will keep the premises reasonably clean, promptly report damage or maintenance needs, and is responsible for damage caused by misuse or negligence.\n\n7. ENTRY\nLandlord may enter only for lawful purposes and with the notice required by the governing jurisdiction, except where emergency entry is legally permitted.\n\n8. DEFAULT AND TERMINATION\nNon-payment or material breach may lead to notices, cure periods, termination or other remedies only as permitted by applicable law. Any early-termination fee or notice period must be written here: ________________________________.\n\n9. INSURANCE / LIABILITY\nRenter's insurance: ____________________. Additional insurance or indemnity terms: ________________________________.\n\n10. GOVERNING LAW / DISPUTES\nGoverning law and venue: ________________________________. Optional mediation/arbitration terms, if lawful and agreed: ________________________________.\n\n11. ADDENDA\nAttached addenda, inventories, disclosures, move-in condition reports, HOA rules or other schedules become part of this agreement when identified and accepted by both parties.\n\n12. ENTIRE AGREEMENT\nThis document and its signed addenda are the entire agreement. Changes must be in writing and accepted by the parties.\n\nLANDLORD SIGNATURE: ____________________ DATE: __________\nTENANT SIGNATURE: ______________________ DATE: __________''',
  ),
  ContractTemplate(
    id: 'lease-month-to-month',
    name: 'Month-to-Month Residential Lease',
    description:
        'Flexible monthly tenancy with notice periods, rent changes, deposit, utilities and core landlord/tenant duties.',
    category: 'Lease',
    forRole: 'both',
    fields: _leaseFields,
    content:
        '''MONTH-TO-MONTH RESIDENTIAL LEASE\n\nEffective Date: {{effective_date}}\nLANDLORD: {{landlord_name}}\nTENANT: {{tenant_name}}\nPROPERTY: {{property_address}}\n\n1. TENANCY\nThe tenancy begins on the effective date and continues month-to-month until terminated with the notice required by applicable law.\n\n2. RENT\nMonthly rent: {{monthly_rent}}. Due date/payment instructions: ________________________________. Rent increases require the notice and limits imposed by local law.\n\n3. DEPOSIT\nSecurity deposit: {{security_deposit}}. Lawful deductions and return timing apply.\n\n4. UTILITIES / HOUSE RULES\nUtilities paid by landlord: ____________________. Utilities paid by tenant: ____________________. Pets, smoking, guests, parking and quiet-hour rules: ________________________________.\n\n5. MAINTENANCE / ENTRY\nLandlord and tenant retain all duties imposed by law. Entry requires lawful notice except in emergencies.\n\n6. TERMINATION\nTenant notice: __________ days. Landlord notice: __________ days, or the minimum required by law if longer.\n\n7. GOVERNING LAW\nJurisdiction: ________________________________.\n\nLANDLORD SIGNATURE: ____________________ DATE: __________\nTENANT SIGNATURE: ______________________ DATE: __________''',
  ),
  ContractTemplate(
    id: 'lease-furnished-apartment',
    name: 'Furnished Apartment Lease',
    description:
        'Lease with furniture inventory, damage/replacement rules, linens, appliances and move-in checklist.',
    category: 'Lease',
    forRole: 'both',
    fields: _leaseFields,
    content:
        '''FURNISHED APARTMENT LEASE AGREEMENT\n\nEffective Date: {{effective_date}}\nLANDLORD: {{landlord_name}}\nTENANT: {{tenant_name}}\nPROPERTY: {{property_address}}\nTERM: {{lease_term}}\nMONTHLY RENT: {{monthly_rent}}\nSECURITY DEPOSIT: {{security_deposit}}\n\n1. FURNISHED PREMISES\nThe premises include the furniture, electronics, kitchenware, linens and other items listed in Schedule A. Tenant acknowledges the move-in condition report and will promptly identify discrepancies.\n\n2. CARE / REPLACEMENT\nTenant will use furnishings reasonably and may be responsible for repair or replacement of missing or damaged items beyond ordinary wear. No landlord-owned furniture may be removed without written consent.\n\n3. INVENTORY SCHEDULE A\nItem / quantity / condition / replacement value:\n____________________________________________________________\n____________________________________________________________\n____________________________________________________________\n\n4. RENT, DEPOSIT, UTILITIES AND RULES\nPayment, deposit, utilities, pet, smoking, guest, parking, maintenance, entry, default and termination terms follow the written terms below and applicable law.\nAdditional terms: ____________________________________________\n\nLANDLORD SIGNATURE: ____________________ DATE: __________\nTENANT SIGNATURE: ______________________ DATE: __________''',
  ),
  ContractTemplate(
    id: 'lease-commercial',
    name: 'Commercial Property Lease',
    description:
        'Office, retail or warehouse lease with permitted use, CAM, insurance, fit-out, signage and renewal options.',
    category: 'Lease',
    forRole: 'both',
    fields: _leaseFields,
    content:
        '''COMMERCIAL LEASE AGREEMENT\n\nEffective Date: {{effective_date}}\nLANDLORD: {{landlord_name}}\nTENANT / BUSINESS: {{tenant_name}}\nPREMISES: {{property_address}}\nTERM: {{lease_term}}\nBASE RENT: {{monthly_rent}}\nDEPOSIT: {{security_deposit}}\n\n1. PERMITTED USE\nThe premises may be used only for: ________________________________. Required business licenses, permits and approvals remain the tenant's responsibility unless otherwise agreed.\n\n2. RENT / OPERATING COSTS\nBase rent, taxes, CAM/common-area charges, insurance allocations, utilities and any percentage rent must be itemized here: ________________________________.\n\n3. FIT-OUT / ALTERATIONS / SIGNAGE\nTenant improvements, restoration obligations, landlord contribution and signage rights: ________________________________.\n\n4. INSURANCE / INDEMNITY\nRequired liability/property coverage and certificate requirements: ________________________________.\n\n5. ASSIGNMENT / SUBLETTING\nAssignment or subletting terms: ________________________________.\n\n6. RENEWAL / DEFAULT / TERMINATION\nRenewal options, cure periods, default remedies and surrender obligations: ________________________________.\n\n7. GOVERNING LAW\nJurisdiction and venue: ________________________________.\n\nLANDLORD SIGNATURE: ____________________ DATE: __________\nTENANT SIGNATURE: ______________________ DATE: __________''',
  ),
  ContractTemplate(
    id: 'lease-room-rental',
    name: 'Room Rental & Sublease Agreement',
    description:
        'Single room in a shared home with house rules, utility split, guest rules, consent and deposit terms.',
    category: 'Lease',
    forRole: 'both',
    fields: _leaseFields,
    content:
        '''ROOM RENTAL & SUBLEASE AGREEMENT\n\nEffective Date: {{effective_date}}\nLANDLORD / HEAD TENANT: {{landlord_name}}\nROOM TENANT: {{tenant_name}}\nPROPERTY: {{property_address}}\nROOM DESCRIPTION: ________________________________\nTERM: {{lease_term}}\nMONTHLY RENT: {{monthly_rent}}\nDEPOSIT: {{security_deposit}}\n\n1. SHARED AREAS\nKitchen / living / bath / laundry / parking access: ________________________________.\n\n2. HOUSE RULES\nQuiet hours, overnight guests, cleaning rotation, kitchen/fridge allocation, pets, smoking, thermostat/AC and common-area conduct: ________________________________.\n\n3. UTILITIES\nIncluded / shared / metered / fixed contribution: ________________________________.\n\n4. MASTER LEASE / CONSENT\nIf this is a sublease, head tenant confirms that any consent required by the master lease or law has been obtained.\n\n5. TERMINATION / MOVE-OUT\nNotice period: __________ days. Keys, cleaning, personal property removal and deposit return will follow this agreement and applicable law.\n\nLANDLORD / HEAD TENANT SIGNATURE: __________ DATE: ________\nROOM TENANT SIGNATURE: _____________________ DATE: ________''',
  ),
  ContractTemplate(
    id: 'long-term-rental-3months',
    name: 'Long-Term Rental Agreement (3+ Months)',
    description:
        'The original Swipess long-stay template for rentals with a minimum three-month term.',
    category: 'Lease',
    forRole: 'both',
    fields: _leaseFields,
    content:
        '''LONG-TERM RENTAL AGREEMENT\nMinimum 3 Month Term\n\nEffective Date: {{effective_date}}\nLANDLORD: {{landlord_name}}\nTENANT: {{tenant_name}}\nPROPERTY: {{property_address}}\nTERM: {{lease_term}}\nMONTHLY RENT: {{monthly_rent}}\nSECURITY DEPOSIT: {{security_deposit}}\n\n1. PROPERTY\nThe landlord rents the identified premises, including any written inventory of furnishings and appliances.\n\n2. TERM\nAfter the initial term, any month-to-month continuation and termination notice will follow the written agreement and applicable law.\n\n3. PAYMENT / UTILITIES\nDue date, late fee, payment method, included utilities and tenant-paid services: ________________________________.\n\n4. RULES\nPets, smoking, subletting, occupants and property rules: ________________________________.\n\n5. MAINTENANCE / TERMINATION\nMaintenance responsibilities and lawful early-termination/default terms: ________________________________.\n\n6. GOVERNING LAW / ADDITIONAL TERMS\n____________________________________________________________\n\nLANDLORD SIGNATURE: ____________________ DATE: __________\nTENANT SIGNATURE: ______________________ DATE: __________''',
  ),
  ContractTemplate(
    id: 'short-term-rental',
    name: 'Short-Term Rental Agreement',
    description:
        'Vacation / temporary stay agreement with dates, guest rules, deposit, cancellation and damage terms.',
    category: 'Rental',
    forRole: 'both',
    fields: _leaseFields,
    content:
        '''SHORT-TERM RENTAL AGREEMENT\n\nAgreement Date: {{effective_date}}\nOWNER / MANAGER: {{landlord_name}}\nGUEST: {{tenant_name}}\nPROPERTY: {{property_address}}\nSTAY DATES: ________________________________\nTOTAL PRICE: ________________________________\nSECURITY / DAMAGE DEPOSIT: {{security_deposit}}\n\n1. OCCUPANCY\nMaximum guests: ______. Only registered guests may occupy the property unless the owner approves otherwise.\n\n2. HOUSE RULES\nSmoking, parties, pets, quiet hours, parking and check-in/out requirements: ________________________________.\n\n3. CANCELLATION / REFUNDS\nCancellation policy: ________________________________.\n\n4. DAMAGE / CONDITION\nGuest will promptly report damage and may be responsible for loss or damage beyond ordinary use, subject to applicable law.\n\n5. SAFETY / LOCAL RULES\nGuest will comply with building, HOA, community and safety requirements provided before signing.\n\nOWNER / MANAGER SIGNATURE: ______________ DATE: ________\nGUEST SIGNATURE: _________________________ DATE: ________''',
  ),
  ContractTemplate(
    id: 'property-sale-contract',
    name: 'Property Sale Contract',
    description:
        'Real estate purchase agreement with price, deposit, inspection, title, closing and default provisions.',
    category: 'Purchase',
    forRole: 'both',
    fields: _saleFields,
    content:
        '''PROPERTY SALE CONTRACT\nReal Estate Purchase Agreement\n\nDate: {{effective_date}}\nSELLER: {{landlord_name}}\nBUYER: {{tenant_name}}\nPROPERTY: {{property_address}}\nPURCHASE PRICE: {{purchase_price}}\nEARNEST MONEY: {{earnest_money}}\nTARGET CLOSING: {{closing_date}}\n\n1. PROPERTY / TITLE\nSeller agrees to sell and buyer agrees to buy the identified property, subject to the title, registry, deed and legal transfer requirements of the governing jurisdiction.\n\n2. PAYMENT\nPayment schedule, financing and escrow/notary instructions: ________________________________.\n\n3. INSPECTION / DUE DILIGENCE\nInspection period, title review, permits, liens, taxes, HOA status and other contingencies: ________________________________.\n\n4. CLOSING COSTS / POSSESSION\nAllocation of taxes, notary/closing fees, commissions, transfer costs and possession date: ________________________________.\n\n5. DEFAULT / REMEDIES\nBuyer and seller remedies, earnest-money treatment and cure rights: ________________________________.\n\n6. GOVERNING LAW\nJurisdiction / venue: ________________________________.\n\nSELLER SIGNATURE: _______________________ DATE: __________\nBUYER SIGNATURE: ________________________ DATE: __________''',
  ),
  ContractTemplate(
    id: 'promise-to-purchase',
    name: 'Promise to Purchase / Reservation',
    description:
        'Pre-closing reservation or promise agreement with deposit, due-diligence period and closing deadline.',
    category: 'Purchase',
    forRole: 'both',
    fields: _saleFields,
    content:
        '''PROMISE TO PURCHASE / RESERVATION AGREEMENT\n\nDate: {{effective_date}}\nSELLER: {{landlord_name}}\nPROSPECTIVE BUYER: {{tenant_name}}\nPROPERTY / ASSET: {{property_address}}\nPROPOSED PRICE: {{purchase_price}}\nRESERVATION / DEPOSIT: {{earnest_money}}\nTARGET CLOSING: {{closing_date}}\n\nThe parties record their intention to proceed toward a definitive purchase agreement, subject to due diligence, title review, financing if applicable, required legal/notarial formalities and any written contingencies below.\n\nDeposit holder and refund/forfeiture terms: ________________________________.\nDue-diligence deadline: ____________________.\nConditions precedent: ____________________________________________.\nExpiration / closing deadline: ____________________________________.\n\nThis document does not replace any deed, notarial act or other form required by applicable law.\n\nSELLER SIGNATURE: _______________________ DATE: __________\nBUYER SIGNATURE: ________________________ DATE: __________''',
  ),
  ContractTemplate(
    id: 'bicycle-rental-agreement',
    name: 'Bicycle Rental Agreement',
    description:
        'Bicycle rental with condition, accessories, safety acknowledgement, damage and return terms.',
    category: 'Vehicle',
    forRole: 'both',
    fields: _vehicleRentalFields,
    content:
        '''BICYCLE RENTAL AGREEMENT\n\nAgreement Date: {{effective_date}}\nOWNER / COMPANY: {{landlord_name}}\nRENTER: {{tenant_name}}\nBICYCLE: {{asset_description}}\nRENTAL FEE: {{rental_fee}}\nSECURITY DEPOSIT: {{security_deposit}}\nRENTAL PERIOD: ________________________________\n\n1. CONDITION / ACCESSORIES\nCondition at release and included helmet, lock, lights, basket or other accessories: ________________________________.\n\n2. SAFE USE\nRenter confirms they can operate the bicycle safely, will obey traffic rules, use required safety equipment and will not use the bicycle for prohibited activity.\n\n3. DAMAGE / LOSS / THEFT\nResponsibility, reporting obligations and replacement/repair limits: ________________________________.\n\n4. RETURN\nReturn location, time, late fee and condition requirements: ________________________________.\n\nOWNER SIGNATURE: ________________________ DATE: __________\nRENTER SIGNATURE: _______________________ DATE: __________''',
  ),
  ContractTemplate(
    id: 'motorcycle-rental-agreement',
    name: 'Motorcycle Rental Agreement',
    description:
        'Motorcycle / scooter rental with license, insurance, condition, restrictions, accident and return terms.',
    category: 'Vehicle',
    forRole: 'both',
    fields: _vehicleRentalFields,
    content:
        '''MOTORCYCLE RENTAL AGREEMENT\n\nAgreement Date: {{effective_date}}\nOWNER / COMPANY: {{landlord_name}}\nRENTER: {{tenant_name}}\nMOTORCYCLE: {{asset_description}}\nRENTAL FEE: {{rental_fee}}\nSECURITY DEPOSIT: {{security_deposit}}\nRENTAL PERIOD: ________________________________\n\n1. DRIVER REQUIREMENTS\nRenter confirms possession of the license/class required by law and agrees to all age, experience and helmet requirements.\n\n2. CONDITION / MILEAGE / FUEL\nStarting odometer, fuel, visible damage, accessories and return standard: ________________________________.\n\n3. INSURANCE\nCoverage, exclusions, deductible and required incident reporting: ________________________________.\n\n4. RESTRICTIONS\nNo racing, stunts, intoxicated operation or prohibited terrain/use. Additional geographic or passenger restrictions: ________________________________.\n\n5. ACCIDENT / THEFT\nRenter will contact authorities when required, notify owner promptly, preserve evidence and cooperate with insurer procedures.\n\nOWNER SIGNATURE: ________________________ DATE: __________\nRENTER SIGNATURE: _______________________ DATE: __________''',
  ),
  ContractTemplate(
    id: 'yacht-charter-agreement',
    name: 'Yacht Charter / Rental Agreement',
    description:
        'Charter terms for a yacht or boat with crew, itinerary, deposit, weather, damage and cancellation clauses.',
    category: 'Vehicle',
    forRole: 'both',
    fields: _vehicleRentalFields,
    content:
        '''YACHT CHARTER / RENTAL AGREEMENT\n\nAgreement Date: {{effective_date}}\nOWNER / OPERATOR: {{landlord_name}}\nCHARTERER: {{tenant_name}}\nVESSEL: {{asset_description}}\nCHARTER FEE: {{rental_fee}}\nSECURITY DEPOSIT: {{security_deposit}}\nCHARTER DATES / HOURS: ________________________________\n\n1. VESSEL / CREW\nVessel registration, captain/crew, passenger limit, included equipment and permitted operating area: ________________________________.\n\n2. ITINERARY / WEATHER\nRequested itinerary is subject to captain discretion, safety, port rules and weather. Rescheduling/cancellation terms for unsafe conditions: ________________________________.\n\n3. FEES / FUEL / GRATUITY\nIncluded and excluded fuel, dockage, provisioning, taxes, crew gratuity and overtime: ________________________________.\n\n4. PASSENGER CONDUCT / SAFETY\nCharterer and guests will follow captain instructions, safety rules and applicable maritime law. Prohibited conduct/items: ________________________________.\n\n5. DAMAGE / DEPOSIT\nDamage, loss and deposit deduction procedures: ________________________________.\n\nOWNER / OPERATOR SIGNATURE: ______________ DATE: ________\nCHARTERER SIGNATURE: ______________________ DATE: ________''',
  ),
  ContractTemplate(
    id: 'service-contract-longterm',
    name: 'Long-Term Service Contract',
    description:
        'Ongoing service engagement with scope, schedule, compensation, materials, confidentiality and termination.',
    category: 'Service',
    forRole: 'both',
    fields: _serviceFields,
    content:
        '''LONG-TERM SERVICE CONTRACT\n\nAgreement Date: {{effective_date}}\nSERVICE PROVIDER: {{landlord_name}}\nCLIENT: {{tenant_name}}\nSERVICES: {{services}}\nCOMPENSATION: {{service_fee}}\nTERM / SCHEDULE: {{service_term}}\n\n1. SCOPE\nProvider will perform the described services professionally and communicate material changes to scope, timing or cost before proceeding.\n\n2. SCHEDULE / ACCESS\nWork days, hours, location, access arrangements and cancellation notice: ________________________________.\n\n3. PAYMENT / EXPENSES\nInvoice cadence, due date, approved expenses, overtime and materials/supplies responsibility: ________________________________.\n\n4. INDEPENDENT STATUS\nUnless the parties and applicable law establish otherwise, provider is engaged as an independent service provider and remains responsible for taxes, licenses and insurance applicable to their business.\n\n5. CONFIDENTIALITY / PROPERTY\nConfidential information, keys/access credentials, client property and work-product ownership: ________________________________.\n\n6. TERMINATION / DISPUTES\nNotice period, immediate-termination grounds and dispute process: ________________________________.\n\nPROVIDER SIGNATURE: _____________________ DATE: __________\nCLIENT SIGNATURE: _______________________ DATE: __________''',
  ),
  ContractTemplate(
    id: 'service-one-time',
    name: 'One-Time Service Agreement',
    description:
        'Simple project/job agreement for cleaning, repair, massage, chef, maintenance or other local services.',
    category: 'Service',
    forRole: 'both',
    fields: _serviceFields,
    content:
        '''ONE-TIME SERVICE AGREEMENT\n\nAgreement Date: {{effective_date}}\nSERVICE PROVIDER: {{landlord_name}}\nCLIENT: {{tenant_name}}\nSCOPE: {{services}}\nFEE: {{service_fee}}\nSCHEDULE: {{service_term}}\n\nDeliverables / completion standard: ________________________________.\nMaterials included/excluded: ______________________________________.\nCancellation / rescheduling: ______________________________________.\nProperty access / safety requirements: _____________________________.\nPayment timing: ___________________________________________________.\nAdditional terms: __________________________________________________.\n\nPROVIDER SIGNATURE: _____________________ DATE: __________\nCLIENT SIGNATURE: _______________________ DATE: __________''',
  ),
  ContractTemplate(
    id: 'independent-contractor',
    name: 'Independent Contractor Agreement',
    description:
        'Professional services agreement with deliverables, fees, confidentiality, IP and independent-contractor terms.',
    category: 'Service',
    forRole: 'both',
    fields: _serviceFields,
    content:
        '''INDEPENDENT CONTRACTOR AGREEMENT\n\nDate: {{effective_date}}\nCONTRACTOR: {{landlord_name}}\nCLIENT: {{tenant_name}}\nSERVICES / DELIVERABLES: {{services}}\nCOMPENSATION: {{service_fee}}\nTERM: {{service_term}}\n\n1. SERVICES / ACCEPTANCE\nMilestones, deliverables and acceptance criteria: ________________________________.\n\n2. FEES / EXPENSES\nInvoice schedule, due dates and pre-approved expenses: ________________________________.\n\n3. INDEPENDENT CONTRACTOR\nContractor controls the manner and means of the services except for agreed deliverables and lawful site/safety requirements, subject to the worker-classification law that actually applies.\n\n4. CONFIDENTIALITY / IP\nConfidentiality, pre-existing materials and ownership/license of work product: ________________________________.\n\n5. WARRANTIES / LIABILITY\nAny warranties, insurance requirements, liability limits and indemnities: ________________________________.\n\n6. TERMINATION / GOVERNING LAW\nNotice, payment for completed work, dispute process and jurisdiction: ________________________________.\n\nCONTRACTOR SIGNATURE: ___________________ DATE: __________\nCLIENT SIGNATURE: _______________________ DATE: __________''',
  ),
  ContractTemplate(
    id: 'vehicle-bill-of-sale',
    name: 'Vehicle / Asset Bill of Sale',
    description:
        'Sale document for motorcycle, bicycle, yacht or other asset with condition, price and transfer terms.',
    category: 'Purchase',
    forRole: 'both',
    fields: _saleFields,
    content:
        '''BILL OF SALE\n\nDate: {{effective_date}}\nSELLER: {{landlord_name}}\nBUYER: {{tenant_name}}\nASSET: {{property_address}}\nPURCHASE PRICE: {{purchase_price}}\nDEPOSIT: {{earnest_money}}\nTRANSFER DATE: {{closing_date}}\n\nSeller transfers the described asset to buyer for the stated consideration, subject to these written terms.\n\nSerial / VIN / registration: ________________________________.\nCondition / disclosed defects: ________________________________.\nIncluded accessories / documents: ________________________________.\nLien / ownership representation: ________________________________.\nTaxes, registration, title/permit transfer responsibility: ________________________________.\nWarranty: ☐ As-is where permitted ☐ Limited warranty attached.\nAdditional terms: _______________________________________________.\n\nSELLER SIGNATURE: _______________________ DATE: __________\nBUYER SIGNATURE: ________________________ DATE: __________''',
  ),
  ContractTemplate(
    id: 'promissory-note',
    name: 'Promissory Note',
    description:
        'Loan repayment note with principal, interest, payment schedule, maturity and default terms.',
    category: 'Finance',
    forRole: 'both',
    fields: _commonPartyFields,
    content:
        '''PROMISSORY NOTE\n\nDate: {{effective_date}}\nLENDER: {{landlord_name}}\nBORROWER: {{tenant_name}}\nPRINCIPAL: ________________________________\nINTEREST RATE: ____________________________\nPAYMENT SCHEDULE: _________________________\nMATURITY DATE: ____________________________\n\nBorrower promises to pay the principal plus any lawful agreed interest according to the payment schedule above. Prepayment terms: ________________________________. Late payment/default remedies and any grace period: ________________________________. Security/collateral, if any: ________________________________. Governing law: ________________________________.\n\nLENDER SIGNATURE: _______________________ DATE: __________\nBORROWER SIGNATURE: _____________________ DATE: __________''',
  ),
  ContractTemplate(
    id: 'mutual-nda',
    name: 'Mutual Confidentiality Agreement',
    description:
        'Two-way NDA for business discussions, property deals, service proposals or partnership conversations.',
    category: 'Business',
    forRole: 'both',
    fields: _commonPartyFields,
    content:
        '''MUTUAL CONFIDENTIALITY AGREEMENT\n\nEffective Date: {{effective_date}}\nPARTY A: {{landlord_name}}\nPARTY B: {{tenant_name}}\nPURPOSE: ________________________________\n\nEach party may disclose non-public business, technical, financial, customer, property or commercial information for the stated purpose. The receiving party will use confidential information only for that purpose, protect it with reasonable care and disclose it only to persons who need it and are bound by confidentiality obligations.\n\nExcluded information includes information already lawfully known, independently developed, publicly available without breach, or lawfully received from a third party. Legally compelled disclosure is permitted subject to any notice legally allowed.\n\nConfidentiality term: ____________________. Return/destruction requirements: ____________________. Governing law: ________________________________.\n\nPARTY A SIGNATURE: ______________________ DATE: __________\nPARTY B SIGNATURE: ______________________ DATE: __________''',
  ),
];

List<ContractTemplate> contractTemplatesForCategory(String? category) {
  if (category == null || category.trim().isEmpty || category == 'All') {
    return contractTemplates;
  }
  return contractTemplates
      .where((template) => template.category == category)
      .toList(growable: false);
}

const contractTemplateCategories = <String>[
  'All',
  'Lease',
  'Rental',
  'Purchase',
  'Vehicle',
  'Service',
  'Finance',
  'Business',
];
