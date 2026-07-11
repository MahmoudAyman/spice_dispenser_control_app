import 'package:flutter/material.dart';

class SettingsTile extends StatelessWidget {

  final IconData icon;

  final String title;

  final String? subtitle;

  final Color? iconColor;

  final VoidCallback onTap;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {

    return Container(

      margin: const EdgeInsets.only(
        bottom: 16,
      ),

      decoration: BoxDecoration(

        color: Colors.white,

        borderRadius:
        BorderRadius.circular(
          24,
        ),

        boxShadow: [

          BoxShadow(

            color: Colors.black
                .withOpacity(
              0.05,
            ),

            blurRadius: 12,

            offset:
            const Offset(
              0,
              4,
            ),
          ),
        ],
      ),

      child: ListTile(

        contentPadding:
        const EdgeInsets.symmetric(
          horizontal: 20,
          vertical: 8,
        ),

        leading: Container(

          width: 48,

          height: 48,

          decoration: BoxDecoration(

            color: (iconColor ??
                const Color(
                  0xFF2563EB,
                ))
                .withOpacity(
              0.12,
            ),

            borderRadius:
            BorderRadius.circular(
              14,
            ),
          ),

          child: Icon(

            icon,

            color:
            iconColor ??
                const Color(
                  0xFF2563EB,
                ),
          ),
        ),

        title: Text(

          title,

          style: const TextStyle(

            fontSize: 17,

            fontWeight:
            FontWeight.w600,
          ),
        ),

        subtitle:
        subtitle != null
            ? Padding(

          padding:
          const EdgeInsets.only(
            top: 4,
          ),

          child: Text(

            subtitle!,

            style: TextStyle(

              color:
              Colors.grey
                  .shade600,

              fontSize: 13,
            ),
          ),
        )
            : null,

        trailing: const Icon(
          Icons.chevron_right,
        ),

        onTap: onTap,
      ),
    );
  }
}