using System;
using System.Linq;
using System.Text;
using System.Text.RegularExpressions;
using JetBrains.Annotations;

namespace XyrusWorx.Management
{
	[PublicAPI]
	public struct SemanticVersion : IComparable<SemanticVersion>, IEquatable<SemanticVersion>
	{
		private readonly int mMajor;
		private readonly int mMinor;
		private readonly int mPatch;
		private readonly string[] mPreRelease;
		private readonly string[] mMetadata;

		public SemanticVersion(int major, int minor)
			: this(major, minor, 0, string.Empty) { }
		public SemanticVersion(int major, int minor, int patch)
			: this(major, minor, patch, string.Empty) { }
		public SemanticVersion(int major, int minor, int patch, string preReleaseIdentifier, params string[] buildMetadata)
			: this(major, minor, patch, new[] { preReleaseIdentifier }.Where(x => !string.IsNullOrEmpty(x)).ToArray(), buildMetadata) { }
		public SemanticVersion(int major, int minor, int patch, string[] preReleaseIdentifiers, string[] buildMetadata)
		{
			if (major < 0) throw new ArgumentOutOfRangeException(nameof(major));
			if (minor < 0) throw new ArgumentOutOfRangeException(nameof(minor));
			if (patch < 0) throw new ArgumentOutOfRangeException(nameof(patch));

			mMajor = major;
			mMinor = minor;
			mPatch = patch;

			var strictAlphanumeric = new Regex("^[0-9A-Za-z-]+$");

			if (preReleaseIdentifiers != null && preReleaseIdentifiers.Any(x => !strictAlphanumeric.IsMatch(x)))
			{
				throw new ArgumentException($"The pre-release identifier is invalid: {string.Join(".", preReleaseIdentifiers)}");
			}

			if (buildMetadata != null && buildMetadata.Any(x => !strictAlphanumeric.IsMatch(x)))
			{
				throw new ArgumentException($"The build metadata is invalid: {string.Join(".", buildMetadata)}");
			}

			mPreRelease = preReleaseIdentifiers ?? new string[0];
			mMetadata = buildMetadata ?? new string[0];
		}

		public int Major => mMajor;
		public int Minor => mMinor;
		public int PatchNumber => mPatch;

		public bool IsEmpty => mMajor == 0 && mMinor == 0 && mPatch == 0 && (mPreRelease == null || mPreRelease.Length == 0) && (mMetadata == null || mMetadata.Length == 0);

		[NotNull]
		public string[] PreReleaseIdentifiers => mPreRelease ?? new string[0];
		public string PreReleaseString => string.Join(".", PreReleaseIdentifiers).NormalizeNull();

		[NotNull]
		public string[] BuildMetadata => mMetadata ?? new string[0];
		public string BuildMetadataString => string.Join(".", BuildMetadata).NormalizeNull();

		[Pure]
		public SemanticVersion RaiseMajor()
		{
			return new SemanticVersion(mMajor + 1, 0, 0, new string[0], BuildMetadata);
		}

		[Pure]
		public SemanticVersion RaiseMinor()
		{
			return new SemanticVersion(mMajor, mMinor + 1, 0, new string[0], BuildMetadata);
		}

		[Pure]
		public SemanticVersion Patch()
		{
			return new SemanticVersion(mMajor, mMinor, mPatch + 1, new string[0], BuildMetadata);
		}

		[Pure]
		public SemanticVersion WithMetadata([NotNull] string[] buildMetadata)
		{
			if (buildMetadata == null || buildMetadata.Length == 0)
			{
				throw new ArgumentNullException(nameof(buildMetadata));
			}

			return new SemanticVersion(mMajor, mMinor, mPatch, PreReleaseIdentifiers, buildMetadata);
		}

		[Pure]
		public SemanticVersion WithMetadata([NotNull] string buildMetadata, params string[] additionalBuildMetadata)
		{
			if (buildMetadata.NormalizeNull() == null)
			{
				throw new ArgumentNullException(nameof(buildMetadata));
			}

			return new SemanticVersion(mMajor, mMinor, mPatch, PreReleaseIdentifiers, new[] { buildMetadata }.Concat(additionalBuildMetadata).ToArray());
		}

		[Pure]
		public SemanticVersion DeclarePreRelease([NotNull] string[] preReleaseIdentifiers)
		{
			if (preReleaseIdentifiers == null || preReleaseIdentifiers.Length == 0)
			{
				throw new ArgumentNullException(nameof(preReleaseIdentifiers));
			}

			return new SemanticVersion(mMajor, mMinor, mPatch, preReleaseIdentifiers, BuildMetadata);
		}

		[Pure]
		public SemanticVersion DeclarePreRelease([NotNull] string prePreleaseIdentifier, params string[] otherPreReleaseIdentifiers)
		{
			if (prePreleaseIdentifier.NormalizeNull() == null)
			{
				throw new ArgumentNullException(nameof(prePreleaseIdentifier));
			}

			return new SemanticVersion(mMajor, mMinor, mPatch, new []{prePreleaseIdentifier}.Concat(otherPreReleaseIdentifiers).ToArray(), BuildMetadata);
		}

		[Pure]
		public SemanticVersion WithoutMetadata()
		{
			return new SemanticVersion(mMajor, mMinor, mPatch, PreReleaseIdentifiers, new string[0]);
		}

		[Pure]
		public SemanticVersion DeclareFinal()
		{
			return new SemanticVersion(mMajor, mMinor, mPatch, new string[0], BuildMetadata);
		}

		[Pure]
		public SemanticVersionRange CompatibleRange()
		{
			var min = new SemanticVersion(mMajor, mMinor);
			var max = new SemanticVersion(mMajor + 1, 0);

			return SemanticVersionRange.BetweenIncludingMinimumWithoutMaximum(min, max);
		}

		public override bool Equals(object obj)
		{
			if (ReferenceEquals(null, obj)) return false;
			return obj is SemanticVersion && Equals((SemanticVersion)obj);
		}
		public override int GetHashCode()
		{
			unchecked
			{
				if (IsEmpty)
				{
					return 0;
				}

				var pre = PreReleaseIdentifiers.Any() ? new StringKeySequence(PreReleaseIdentifiers) : new StringKeySequence();
				var hashCode = 17;

				hashCode = (hashCode * 397) ^ mMajor;
				hashCode = (hashCode * 397) ^ mMinor;
				hashCode = (hashCode * 397) ^ mPatch;
				hashCode = (hashCode * 397) ^ pre.GetHashCode();

				return hashCode;
			}
		}
		public override string ToString()
		{
			return ToString(true);
		}

		public static bool operator ==(SemanticVersion left, SemanticVersion right)
		{
			return left.Equals(right);
		}
		public static bool operator !=(SemanticVersion left, SemanticVersion right)
		{
			return !left.Equals(right);
		}
		public static bool operator <(SemanticVersion left, SemanticVersion right)
		{
			return left.CompareTo(right) > 0;
		}
		public static bool operator >(SemanticVersion left, SemanticVersion right)
		{
			return left.CompareTo(right) < 0;
		}

		[Pure]
		public int CompareTo(SemanticVersion other)
		{
			const int larger = 1;
			const int smaller = -1;
			const int equal = 0;

			if (IsEmpty && other.IsEmpty) return equal;
			if (IsEmpty && !other.IsEmpty) return smaller;
			if (!IsEmpty && other.IsEmpty) return larger;

			if (mMajor > other.mMajor) return larger;
			if (mMajor < other.mMajor) return smaller;

			if (mMinor > other.mMinor) return larger;
			if (mMinor < other.mMinor) return smaller;

			if (mPatch > other.mPatch) return larger;
			if (mPatch < other.mPatch) return smaller;

			if (!PreReleaseIdentifiers.Any() && other.PreReleaseIdentifiers.Any()) return larger;
			if (PreReleaseIdentifiers.Any() && !other.PreReleaseIdentifiers.Any()) return smaller;

			if (PreReleaseIdentifiers.Length > other.PreReleaseIdentifiers.Length) return larger;
			if (PreReleaseIdentifiers.Length < other.PreReleaseIdentifiers.Length) return smaller;

			var num = new Regex("^[0-9]+$", RegexOptions.Compiled);

			for (var i = 0; i < PreReleaseIdentifiers.Length; i++)
			{
				var pThis = PreReleaseIdentifiers[i];
				var pOther = other.PreReleaseIdentifiers[i];

				if (num.IsMatch(pThis) && !num.IsMatch(pOther)) return smaller;
				if (!num.IsMatch(pThis) && num.IsMatch(pOther)) return larger;

				if (num.IsMatch(pThis) && num.IsMatch(pOther))
				{
					var iThis = int.Parse(pThis);
					var iOther = int.Parse(pOther);

					if (iThis == iOther)
					{
						continue;
					}

					return iThis.CompareTo(iOther);
				}

				if (string.Equals(pThis, pOther, StringComparison.Ordinal))
				{
					continue;
				}

				return string.Compare(pThis, pOther, StringComparison.Ordinal);
			}

			return equal;
		}

		[Pure]
		public bool Equals(SemanticVersion other)
		{
			if (IsEmpty && other.IsEmpty)
			{
				return true;
			}

			if (IsEmpty != other.IsEmpty)
			{
				return false;
			}

			var preA = PreReleaseIdentifiers.Any() ? new StringKeySequence(PreReleaseIdentifiers) : new StringKeySequence();
			var preB = other.PreReleaseIdentifiers.Any() ? new StringKeySequence(other.PreReleaseIdentifiers) : new StringKeySequence();

			return
				mMajor == other.mMajor &&
				mMinor == other.mMinor &&
				mPatch == other.mPatch &&
				preA.Equals(preB);
		}

		[Pure]
		public string ToString(bool includeMetadata)
		{
			if (IsEmpty)
			{
				return "0.0.0";
			}

			var sb = new StringBuilder();

			sb.AppendFormat("{0}.{1}.{2}", mMajor, mMinor, mPatch);

			for (var iPre = 0; iPre < PreReleaseIdentifiers.Length; iPre++)
			{
				sb.AppendFormat("{1}{0}", PreReleaseIdentifiers[iPre], iPre == 0 ? '-' : '.');
			}

			if (includeMetadata)
			{
				for (var iMeta = 0; iMeta < BuildMetadata.Length; iMeta++)
				{
					sb.AppendFormat("{1}{0}", BuildMetadata[iMeta], iMeta == 0 ? '+' : '.');
				}
			}

			return sb.ToString();
		}

		public static SemanticVersion Empty => new SemanticVersion();
		public static SemanticVersion Parse(string versionString)
		{
			if (!TryParse(versionString, out var version))
			{
				throw new FormatException();
			}

			return version;
		}

		public static bool TryParse(string versionString, out SemanticVersion version)
		{
			var regex = new Regex(@"^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-([\da-z\-]+(?:\.[\da-z\-]+)*))?(?:\+([\da-z\-]+(?:\.[\da-z\-]+)*))?$", RegexOptions.IgnoreCase);
			var match = regex.Match(versionString ?? string.Empty);

			if (!match.Success)
			{
				version = default(SemanticVersion);
				return false;
			}

			var major = int.Parse(match.Groups[1].Value);
			var minor = int.Parse(match.Groups[2].Value);
			var patch = int.Parse(match.Groups[3].Value);

			var preRelease = match.Groups[4].Value.Split(new[]{ '.' }, StringSplitOptions.RemoveEmptyEntries);
			var metadata = match.Groups[5].Value.Split(new[] { '.' }, StringSplitOptions.RemoveEmptyEntries);

			version = new SemanticVersion(major, minor, patch, preRelease, metadata);
			return true;
		}
	}
}