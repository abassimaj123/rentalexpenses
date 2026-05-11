import 'package:flutter/material.dart';

enum LeaseStatus { active, expiringSoon, expired }

class Tenant {
  final String id;
  final String propertyId;
  final String name;
  final String email;
  final String phone;
  final double monthlyRent;
  final DateTime leaseStart;
  final DateTime leaseEnd;
  final String notes;
  final DateTime createdAt;

  const Tenant({
    required this.id,
    required this.propertyId,
    required this.name,
    required this.email,
    required this.phone,
    required this.monthlyRent,
    required this.leaseStart,
    required this.leaseEnd,
    required this.notes,
    required this.createdAt,
  });

  LeaseStatus get status {
    final now = DateTime.now();
    if (leaseEnd.isBefore(now)) return LeaseStatus.expired;
    final daysLeft = leaseEnd.difference(now).inDays;
    if (daysLeft <= 60) return LeaseStatus.expiringSoon;
    return LeaseStatus.active;
  }

  int get daysRemaining {
    final now = DateTime.now();
    return leaseEnd.difference(now).inDays;
  }

  Color get statusColor {
    switch (status) {
      case LeaseStatus.active:
        return const Color(0xFF34C759);
      case LeaseStatus.expiringSoon:
        return const Color(0xFFFFA500);
      case LeaseStatus.expired:
        return Colors.red;
    }
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'property_id': propertyId,
        'name': name,
        'email': email,
        'phone': phone,
        'monthly_rent': monthlyRent,
        'lease_start': leaseStart.toIso8601String(),
        'lease_end': leaseEnd.toIso8601String(),
        'notes': notes,
        'created_at': createdAt.toIso8601String(),
      };

  factory Tenant.fromMap(Map<String, dynamic> m) => Tenant(
        id: m['id'] as String,
        propertyId: m['property_id'] as String,
        name: m['name'] as String,
        email: m['email'] as String? ?? '',
        phone: m['phone'] as String? ?? '',
        monthlyRent: (m['monthly_rent'] as num).toDouble(),
        leaseStart: DateTime.parse(m['lease_start'] as String),
        leaseEnd: DateTime.parse(m['lease_end'] as String),
        notes: m['notes'] as String? ?? '',
        createdAt: DateTime.parse(m['created_at'] as String),
      );

  Tenant copyWith({
    String? name,
    String? email,
    String? phone,
    double? monthlyRent,
    DateTime? leaseStart,
    DateTime? leaseEnd,
    String? notes,
  }) =>
      Tenant(
        id: id,
        propertyId: propertyId,
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        monthlyRent: monthlyRent ?? this.monthlyRent,
        leaseStart: leaseStart ?? this.leaseStart,
        leaseEnd: leaseEnd ?? this.leaseEnd,
        notes: notes ?? this.notes,
        createdAt: createdAt,
      );
}
