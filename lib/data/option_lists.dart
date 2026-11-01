/// Selectable values for onboarding and filters. Server config can override
/// these later; the app always has a working list.
class OptionLists {
  OptionLists._();

  static const List<String> maritalStatus = <String>[
    'Never married',
    'Divorced',
    'Widowed',
  ];

  static const List<String> marriageReadiness = <String>[
    'Actively looking to marry now',
    'Ready within 6 months',
    'Ready within 1 year',
    'Planning for the future',
    'Just exploring',
  ];

  static const String beyondCaste = 'Beyond Caste';

  static const List<String> castes = <String>[
    beyondCaste,
    'Syed',
    'Shaikh',
    'Pathan',
    'Khan',
    'Mughal',
    'Ansari',
    'Qureshi',
    'Siddiqui',
    'Rajput',
    'Malik',
    'Other',
  ];

  /// Value is whether the qualification meets the graduates-only rule.
  static const Map<String, bool> qualifications = <String, bool>{
    'Pursuing Bachelor\'s': true,
    'B.Tech / BE': true,
    'BA': true,
    'B.Sc': true,
    'B.Com': true,
    'BBA': true,
    'BCA': true,
    'LLB': true,
    'MBBS': true,
    'BDS': true,
    'B.Pharm': true,
    'B.Arch': true,
    'M.Tech / ME': true,
    'MA': true,
    'M.Sc': true,
    'M.Com': true,
    'MBA': true,
    'MCA': true,
    'LLM': true,
    'MD / MS': true,
    'PhD': true,
    'Diploma': false,
    'Higher Secondary': false,
    'Other': false,
  };

  static const List<String> professions = <String>[
    'Software Engineer / Developer',
    'Engineer',
    'Doctor',
    'Dentist',
    'Pharmacist',
    'Nurse / Healthcare',
    'Lawyer',
    'Chartered Accountant',
    'Finance / Banking',
    'Teacher / Lecturer',
    'Researcher / Scientist',
    'Civil Services',
    'Architect',
    'Designer',
    'Creative / Media',
    'Marketing / Sales',
    'Consultant',
    'Business / Self-Employed',
    'Student',
    'Homemaker',
    'Other',
  ];

  static const List<String> incomeRanges = <String>[
    'Prefer not to say',
    'Up to ₹5 Lakh',
    '₹5–10 Lakh',
    '₹10–20 Lakh',
    '₹20–50 Lakh',
    '₹50 Lakh – ₹1 Crore',
    'Above ₹1 Crore',
  ];

  static List<String> get heights => <String>[
        for (int feet = 4; feet <= 6; feet++)
          for (int inch = 0; inch < 12; inch++)
            if (!(feet == 4 && inch < 6)) '$feet\'$inch"',
        '7\'0"',
      ];

  static const String otherUniversity = 'Not in the list (Other)';

  /// Grouped by country. The two most common come first in India.
  static const Map<String, List<String>> universities = <String, List<String>>{
    'India': <String>[
      'Aligarh Muslim University',
      'Jamia Millia Islamia',
      'AIIMS',
      'Amity University',
      'Anna University',
      'Banaras Hindu University',
      'BITS Pilani',
      'Calcutta University',
      'Delhi University',
      'Guru Gobind Singh Indraprastha University',
      'Hamdard University',
      'IISc Bangalore',
      'IIM Ahmedabad',
      'IIM Bangalore',
      'IIM Calcutta',
      'IIT Bombay',
      'IIT Delhi',
      'IIT Kanpur',
      'IIT Kharagpur',
      'IIT Madras',
      'Integral University',
      'Jadavpur University',
      'Jawaharlal Nehru University',
      'Lucknow University',
      'Maulana Azad National Urdu University',
      'Mumbai University',
      'NIT Srinagar',
      'NIT Trichy',
      'Osmania University',
      'Pune University',
      'University of Hyderabad',
      'VIT Vellore',
    ],
    'United States': <String>[
      'Harvard University',
      'Massachusetts Institute of Technology',
      'New York University',
      'Stanford University',
      'University of Michigan',
      'Yale University',
    ],
    'United Kingdom': <String>[
      'Imperial College London',
      'King\'s College London',
      'University of Cambridge',
      'University of Manchester',
      'University of Oxford',
    ],
    'United Arab Emirates': <String>[
      'American University of Sharjah',
      'Khalifa University',
      'University of Dubai',
    ],
    'Canada': <String>[
      'McGill University',
      'University of British Columbia',
      'University of Toronto',
    ],
    'Pakistan': <String>[
      'Aga Khan University',
      'LUMS',
      'NUST',
      'University of Karachi',
    ],
  };

  /// Country → region → cities.
  static const Map<String, Map<String, List<String>>> locations =
      <String, Map<String, List<String>>>{
    'India': <String, List<String>>{
      'Andhra Pradesh': <String>['Visakhapatnam', 'Vijayawada', 'Kurnool'],
      'Assam': <String>['Guwahati', 'Silchar'],
      'Bihar': <String>['Patna', 'Gaya', 'Bettiah', 'Darbhanga', 'Muzaffarpur', 'Siwan'],
      'Delhi': <String>['Delhi', 'Okhla (Jamia Nagar)', 'Rohini', 'Dwarka'],
      'Gujarat': <String>['Ahmedabad', 'Surat', 'Vadodara'],
      'Haryana': <String>['Gurugram', 'Faridabad'],
      'Jammu & Kashmir': <String>['Srinagar', 'Jammu'],
      'Jharkhand': <String>['Ranchi', 'Jamshedpur', 'Dhanbad'],
      'Karnataka': <String>['Bengaluru', 'Mangaluru', 'Mysuru', 'Gulbarga'],
      'Kerala': <String>['Kochi', 'Kozhikode', 'Malappuram', 'Thiruvananthapuram'],
      'Madhya Pradesh': <String>['Bhopal', 'Indore'],
      'Maharashtra': <String>['Mumbai', 'Pune', 'Aurangabad', 'Nagpur', 'Malegaon'],
      'Rajasthan': <String>['Jaipur', 'Ajmer', 'Jodhpur'],
      'Tamil Nadu': <String>['Chennai', 'Coimbatore', 'Madurai'],
      'Telangana': <String>['Hyderabad'],
      'Uttar Pradesh': <String>['Aligarh', 'Lucknow', 'Noida', 'Ghaziabad', 'Kanpur', 'Meerut', 'Moradabad', 'Prayagraj', 'Rampur', 'Varanasi'],
      'Uttarakhand': <String>['Dehradun', 'Haridwar'],
      'West Bengal': <String>['Kolkata', 'Asansol', 'Murshidabad'],
    },
    'United Arab Emirates': <String, List<String>>{
      'Abu Dhabi': <String>['Abu Dhabi', 'Al Ain'],
      'Dubai': <String>['Dubai'],
      'Sharjah': <String>['Sharjah'],
    },
    'Saudi Arabia': <String, List<String>>{
      'Eastern Province': <String>['Dammam', 'Al Khobar'],
      'Makkah': <String>['Jeddah', 'Makkah'],
      'Riyadh': <String>['Riyadh'],
    },
    'Pakistan': <String, List<String>>{
      'Punjab': <String>['Lahore', 'Rawalpindi'],
      'Sindh': <String>['Karachi'],
      'Islamabad': <String>['Islamabad'],
    },
    'United Kingdom': <String, List<String>>{
      'England': <String>['London', 'Birmingham', 'Manchester', 'Leeds', 'Bradford'],
      'Scotland': <String>['Glasgow', 'Edinburgh'],
    },
    'United States': <String, List<String>>{
      'California': <String>['Los Angeles', 'San Francisco', 'San Jose'],
      'New York': <String>['New York'],
      'New Jersey': <String>['Jersey City'],
      'Texas': <String>['Houston', 'Dallas', 'Austin'],
      'Illinois': <String>['Chicago'],
      'Michigan': <String>['Detroit'],
    },
    'Canada': <String, List<String>>{
      'Ontario': <String>['Toronto', 'Ottawa', 'Mississauga'],
      'Quebec': <String>['Montreal'],
      'British Columbia': <String>['Vancouver'],
      'Alberta': <String>['Calgary', 'Edmonton'],
    },
  };

  static const Map<String, String> countryCodes = <String, String>{
    '+91': 'IN',
    '+971': 'AE',
    '+966': 'SA',
    '+92': 'PK',
    '+44': 'UK',
    '+1': 'US',
  };
}
