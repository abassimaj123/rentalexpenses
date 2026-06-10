import 'package:calcwise_core/calcwise_core.dart';
import 'package:flutter/material.dart';
import '../models/tenant_model.dart';

extension TenantColorsX on Tenant {
  Color get statusColor {
    switch (status) {
      case LeaseStatus.active:
        return CalcwiseSemanticColors.successDark;
      case LeaseStatus.expiringSoon:
        return CalcwiseSemanticColors.warnIcon;
      case LeaseStatus.expired:
        return CalcwiseSemanticColors.errorIcon;
    }
  }
}
