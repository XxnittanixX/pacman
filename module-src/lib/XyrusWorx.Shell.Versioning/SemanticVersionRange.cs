using System;
using System.Text.RegularExpressions;
using JetBrains.Annotations;

namespace XyrusWorx
{
	[PublicAPI]
	public struct SemanticVersionRange : IEquatable<SemanticVersionRange>
	{
		private SemanticVersionRange(SemanticVersion min, SemanticVersion max, bool leftInclusive, bool rightInclusive)
		{
			Minimum = min;
			Maxmimum = max;
			IsMinimumInclusive = leftInclusive;
			IsMaximumInclusive = rightInclusive;
		}

		public SemanticVersion Minimum { get; }
		public SemanticVersion Maxmimum { get; }

		public bool IsMinimumInclusive { get; }
		public bool IsMaximumInclusive { get; }

		public bool IsEmpty
		{
			get => Minimum.IsEmpty && Maxmimum.IsEmpty;
		}
		public bool IsExact
		{
			get => !IsEmpty && Minimum == Maxmimum;
		}

		public static SemanticVersionRange Any() => default(SemanticVersionRange);
		public static SemanticVersionRange Exactly(SemanticVersion version) => version.IsEmpty ? Any() : new SemanticVersionRange(version, version, true, true);

		public static SemanticVersionRange AtLeastIncluding(SemanticVersion version) => version.IsEmpty ? Any() : new SemanticVersionRange(version, default(SemanticVersion), true, false);
		public static SemanticVersionRange AtLeastWithout(SemanticVersion version) => version.IsEmpty ? Any() : new SemanticVersionRange(version, default(SemanticVersion), false, false);
		public static SemanticVersionRange UntilIncluding(SemanticVersion version) => version.IsEmpty ? Any() : new SemanticVersionRange(default(SemanticVersion), version, false, true);
		public static SemanticVersionRange UntilWithout(SemanticVersion version) => version.IsEmpty ? Any() : new SemanticVersionRange(default(SemanticVersion), version, false, false);
		public static SemanticVersionRange BetweenIncluding(SemanticVersion minimumVersion, SemanticVersion maximumVersion)
		{
			if (minimumVersion.IsEmpty && maximumVersion.IsEmpty)
			{
				return Any();
			}

			if (maximumVersion.IsEmpty)
			{
				return AtLeastIncluding(minimumVersion);
			}

			return minimumVersion.IsEmpty ? UntilIncluding(maximumVersion) : new SemanticVersionRange(minimumVersion, maximumVersion, true, true);

		}
		public static SemanticVersionRange BetweenWithout(SemanticVersion minimumVersion, SemanticVersion maximumVersion)
		{
			if (minimumVersion.IsEmpty && maximumVersion.IsEmpty)
			{
				return Any();
			}

			if (maximumVersion.IsEmpty)
			{
				return AtLeastWithout(minimumVersion);
			}

			return minimumVersion.IsEmpty ? UntilWithout(maximumVersion) : new SemanticVersionRange(minimumVersion, maximumVersion, false, false);

		}
		public static SemanticVersionRange BetweenWithoutMinimumIncludingMaximum(SemanticVersion minimumVersion, SemanticVersion maximumVersion)
		{
			if (minimumVersion.IsEmpty && maximumVersion.IsEmpty)
			{
				return Any();
			}

			if (maximumVersion.IsEmpty)
			{
				return AtLeastWithout(minimumVersion);
			}

			return minimumVersion.IsEmpty ? UntilIncluding(maximumVersion) : new SemanticVersionRange(minimumVersion, maximumVersion, false, true);

		}
		public static SemanticVersionRange BetweenIncludingMinimumWithoutMaximum(SemanticVersion minimumVersion, SemanticVersion maximumVersion)
		{
			if (minimumVersion.IsEmpty && maximumVersion.IsEmpty)
			{
				return Any();
			}

			if (maximumVersion.IsEmpty)
			{
				return AtLeastIncluding(minimumVersion);
			}

			return minimumVersion.IsEmpty ? UntilWithout(maximumVersion) : new SemanticVersionRange(minimumVersion, maximumVersion, true, false);

		}

		public override bool Equals(object obj)
		{
			if (ReferenceEquals(null, obj))
			{
				return false;
			}
			return obj is SemanticVersionRange range && Equals(range);
		}
		public override int GetHashCode()
		{
			unchecked
			{
				var hashCode = 17;

				hashCode = (hashCode * 397) ^ Minimum.GetHashCode();
				hashCode = (hashCode * 397) ^ Maxmimum.GetHashCode();
				hashCode = (hashCode * 397) ^ IsMinimumInclusive.GetHashCode();
				hashCode = (hashCode * 397) ^ IsMaximumInclusive.GetHashCode();

				return hashCode;
			}
		}
		public override string ToString()
		{
			if (Minimum.IsEmpty && Maxmimum.IsEmpty)
			{
				return string.Empty;
			}

			if (!Minimum.IsEmpty && Maxmimum.IsEmpty)
			{
				return IsMinimumInclusive ? Minimum.ToString(false) : $"({Minimum.ToString(false)},)";

			}

			if (Minimum.IsEmpty && !Maxmimum.IsEmpty)
			{
				if (IsMaximumInclusive)
				{
					return $"(,{Maxmimum.ToString(false)}]";
				}

				return $"(,{Maxmimum.ToString(false)})";
			}

			return Minimum == Maxmimum 

				? $"[{Minimum.ToString(false)}]" 
				: $"{(IsMinimumInclusive ? "[" : "(")}{Minimum.ToString(false)},{Maxmimum.ToString(false)}{(IsMaximumInclusive ? "]" : ")")}";
		}

		public static bool operator ==(SemanticVersionRange left, SemanticVersionRange right) => left.Equals(right);
		public static bool operator !=(SemanticVersionRange left, SemanticVersionRange right) => !left.Equals(right);

		[Pure]
		public bool Equals(SemanticVersionRange other) => Minimum.Equals(other.Minimum) &&
			Maxmimum.Equals(other.Maxmimum) &&
			IsMinimumInclusive == other.IsMinimumInclusive &&
			IsMaximumInclusive == other.IsMaximumInclusive;

		public static SemanticVersionRange Parse(string versionString)
		{
			if (!TryParse(versionString, out var version))
			{
				throw new FormatException();
			}

			return version;
		}
		public static bool TryParse(string rangeString, out SemanticVersionRange range)
		{
			var regex = new Regex(@"^(\(|\[)?(,?(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:\.(?:0|[1-9]\d*))?(?:,(?:0|[1-9]\d*)\.(?:0|[1-9]\d*)(?:\.(?:0|[1-9]\d*))?)?,?)(\)|\])?$", RegexOptions.IgnoreCase);
			var match = regex.Match(rangeString ?? string.Empty);

			if (!match.Success)
			{
				range = default(SemanticVersionRange);
				return false;
			}

			var leftInclusiveToken = match.Groups[1].Value;
			var rightInclusiveToken = match.Groups[3].Value;
			var versionTokens = match.Groups[2].Value.Split(',');

			if (versionTokens.Length == 0)
			{
				range = default(SemanticVersionRange);
				return false;
			}

			if (versionTokens.Length == 1)
			{
				if (SemanticVersion.TryParse(versionTokens[0], out var version) && leftInclusiveToken == "[" && rightInclusiveToken == "]")
				{
					range = Exactly(version);
					return true;
				}

				range = default(SemanticVersionRange);
				return false;
			}

			if (versionTokens.Length == 2)
			{
				if (string.IsNullOrWhiteSpace(versionTokens[0]) && !string.IsNullOrWhiteSpace(versionTokens[1]))
				{
					if (SemanticVersion.TryParse(versionTokens[1], out var version) && leftInclusiveToken == "(")
					{
						range = rightInclusiveToken == "]" ? UntilIncluding(version) : UntilWithout(version);
						return true;
					}
				}

				if (!string.IsNullOrWhiteSpace(versionTokens[0]) && string.IsNullOrWhiteSpace(versionTokens[1]))
				{
					if (SemanticVersion.TryParse(versionTokens[0], out var version) && rightInclusiveToken == ")")
					{
						range = leftInclusiveToken == "[" ? AtLeastIncluding(version) : AtLeastWithout(version);
						return true;
					}
				}

				if (!string.IsNullOrWhiteSpace(versionTokens[0]) && !string.IsNullOrWhiteSpace(versionTokens[1]))
				{
					if (SemanticVersion.TryParse(versionTokens[0], out var minVersion) && SemanticVersion.TryParse(versionTokens[1], out var maxVersion))
					{
						range = new SemanticVersionRange(minVersion, maxVersion, leftInclusiveToken == "[", rightInclusiveToken == "]");
						return true;
					}
				}

				range = default(SemanticVersionRange);
				return false;
			}

			range = default(SemanticVersionRange);
			return false;
		}
	}
}