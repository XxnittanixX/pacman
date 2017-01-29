using System;
using System.Text.RegularExpressions;
using JetBrains.Annotations;

namespace XyrusWorx.Management
{
	[PublicAPI]
	public struct SemanticVersionRange : IEquatable<SemanticVersionRange>
	{
		private readonly SemanticVersion mMin;
		private readonly SemanticVersion mMax;
		private readonly bool mLeftInclusive;
		private readonly bool mRightInclusive;

		private SemanticVersionRange(SemanticVersion min, SemanticVersion max, bool leftInclusive, bool rightInclusive)
		{
			mMin = min;
			mMax = max;
			mLeftInclusive = leftInclusive;
			mRightInclusive = rightInclusive;
		}

		public SemanticVersion Minimum => mMin;
		public SemanticVersion Maxmimum => mMax;

		public bool IsMinimumInclusive => mLeftInclusive;
		public bool IsMaximumInclusive => mRightInclusive;

		public bool IsEmpty => mMin.IsEmpty && mMax.IsEmpty;
		public bool IsExact => !IsEmpty && mMin == mMax;

		public static SemanticVersionRange Any() => default(SemanticVersionRange);
		public static SemanticVersionRange Exactly(SemanticVersion version)
		{
			if (version.IsEmpty)
			{
				return Any();
			}

			return new SemanticVersionRange(version, version, true, true);
		}
		public static SemanticVersionRange AtLeastIncluding(SemanticVersion version)
		{
			if (version.IsEmpty)
			{
				return Any();
			}

			return new SemanticVersionRange(version, default(SemanticVersion), true, false);
		}
		public static SemanticVersionRange AtLeastWithout(SemanticVersion version)
		{
			if (version.IsEmpty)
			{
				return Any();
			}

			return new SemanticVersionRange(version, default(SemanticVersion), false, false);
		}
		public static SemanticVersionRange UntilIncluding(SemanticVersion version)
		{
			if (version.IsEmpty)
			{
				return Any();
			}

			return new SemanticVersionRange(default(SemanticVersion), version, false, true);
		}
		public static SemanticVersionRange UntilWithout(SemanticVersion version)
		{
			if (version.IsEmpty)
			{
				return Any();
			}

			return new SemanticVersionRange(default(SemanticVersion), version, false, false);
		}
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

			if (minimumVersion.IsEmpty)
			{
				return UntilIncluding(maximumVersion);
			}

			return new SemanticVersionRange(minimumVersion, maximumVersion, true, true);
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

			if (minimumVersion.IsEmpty)
			{
				return UntilWithout(maximumVersion);
			}

			return new SemanticVersionRange(minimumVersion, maximumVersion, false, false);
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

			if (minimumVersion.IsEmpty)
			{
				return UntilIncluding(maximumVersion);
			}

			return new SemanticVersionRange(minimumVersion, maximumVersion, false, true);
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

			if (minimumVersion.IsEmpty)
			{
				return UntilWithout(maximumVersion);
			}

			return new SemanticVersionRange(minimumVersion, maximumVersion, true, false);
		}

		public override bool Equals(object obj)
		{
			if (ReferenceEquals(null, obj)) return false;
			return obj is SemanticVersionRange && Equals((SemanticVersionRange) obj);
		}
		public override int GetHashCode()
		{
			unchecked
			{
				var hashCode = 17;

				hashCode = (hashCode * 397) ^ mMin.GetHashCode();
				hashCode = (hashCode * 397) ^ mMax.GetHashCode();
				hashCode = (hashCode * 397) ^ mLeftInclusive.GetHashCode();
				hashCode = (hashCode * 397) ^ mRightInclusive.GetHashCode();

				return hashCode;
			}
		}
		public override string ToString()
		{
			if (mMin.IsEmpty && mMax.IsEmpty)
			{
				return string.Empty;
			}

			if (!mMin.IsEmpty && mMax.IsEmpty)
			{
				if (mLeftInclusive)
				{
					return mMin.ToString(false);
				}

				return $"({mMin.ToString(false)},)";
			}

			if (mMin.IsEmpty && !mMax.IsEmpty)
			{
				if (mRightInclusive)
				{
					return $"(,{mMax.ToString(false)}]";
				}

				return $"(,{mMax.ToString(false)})";
			}

			return mMin == mMax 

				? $"[{mMin.ToString(false)}]" 
				: $"{(mLeftInclusive ? "[" : "(")}{mMin.ToString(false)},{mMax.ToString(false)}{(mRightInclusive ? "]" : ")")}";
		}

		public static bool operator ==(SemanticVersionRange left, SemanticVersionRange right)
		{
			return left.Equals(right);
		}
		public static bool operator !=(SemanticVersionRange left, SemanticVersionRange right)
		{
			return !left.Equals(right);
		}

		[Pure]
		public bool Equals(SemanticVersionRange other)
		{
			return
				mMin.Equals(other.mMin) &&
				mMax.Equals(other.mMax) &&
				mLeftInclusive == other.mLeftInclusive &&
				mRightInclusive == other.mRightInclusive;
		}

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